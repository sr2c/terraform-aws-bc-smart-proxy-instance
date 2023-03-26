module "conf_log" {
  source              = "sr2c/ec2-conf-log/aws"
  version             = "0.0.3"
  context             = module.this.context
  disable_logs_bucket = true
}

data "cloudinit_config" "this" {
  base64_encode = true
  gzip          = true

  part {
    content = templatefile("${path.module}/templates/user_data.yaml", {
      configure_script = jsonencode(templatefile("${path.module}/templates/configure.sh",
      { bucket_name = module.conf_log.conf_bucket_id })),
      crontab     = jsonencode(file("${path.module}/templates/cron")),
      certificate = jsonencode("${acme_certificate.this.certificate_pem}${acme_certificate.this.issuer_pem}"),
      private_key = jsonencode(tls_private_key.cert_private_key.private_key_pem)
    })
    content_type = "text/cloud-config"
    filename     = "user_data.yaml"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "default" {
  availability_zone = data.aws_availability_zones.available.names[0]
  default_for_az    = true
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

module "instance" {
  source  = "cloudposse/ec2-instance/aws"
  version = "0.42.0"

  subnet                      = data.aws_subnet.default.id
  vpc_id                      = data.aws_vpc.default.id
  ami                         = data.aws_ami.ubuntu.id
  ami_owner                   = "099720109477"
  assign_eip_address          = true
  associate_public_ip_address = true
  disable_api_termination     = var.disable_api_termination
  instance_type               = "t3.medium"
  instance_profile            = module.conf_log.instance_profile_name
  user_data_base64            = data.cloudinit_config.this.rendered
  security_group_rules = [
    {
      "cidr_blocks" : ["0.0.0.0/0"],
      "description" : "Allow all outbound traffic",
      "from_port" : 0, "protocol" : "-1", "to_port" : 65535,
      "type" : "egress"
    },
    {
      "cidr_blocks" : ["0.0.0.0/0"],
      "description" : "Allow all inbound HTTP traffic",
      "from_port" : 80, "protocol" : "tcp", "to_port" : 80,
      "type" : "ingress"
    },
    {
      "cidr_blocks" : ["0.0.0.0/0"],
      "description" : "Allow all inbound HTTPS traffic",
      "from_port" : 443, "protocol" : "tcp", "to_port" : 443,
      "type" : "ingress"
    }
  ]

  context = module.this.context
  tags    = { Application = "smart-proxy" }

  depends_on = [
    aws_s3_object.smart_config,
  ]
}

data "aws_route53_zone" "this" {
  name = trimsuffix(var.dns_zone, ".")
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.id
  name    = "*.${module.this.id}"
  type    = "A"
  ttl     = 180

  records = [
    module.instance.public_ip
  ]
}

resource "aws_s3_object" "smart_config" {
  bucket = module.conf_log.conf_bucket_id
  key    = "default"
  source = var.config_filename
  etag   = filemd5(var.config_filename)
}

resource "aws_iam_policy" "dns_validation" {
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect   = "Allow"
        Action   = "route53:ListHostedZonesByName"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${data.aws_route53_zone.this.id}"
        ]
        Condition = {
          "ForAllValues:StringEquals" = {
            "route53:ChangeResourceRecordSetsNormalizedRecordNames" = [
              "_acme-challenge.${module.this.id}.${var.dns_zone}"
            ]
            "route53:ChangeResourceRecordSetsRecordTypes" : [
              "TXT"
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_user" "dns_validation" {
  name = "${module.this.id}${module.this.delimiter}acme${module.this.delimiter}validation"
}

resource "aws_iam_access_key" "dns_validation" {
  user = aws_iam_user.dns_validation.name
}

resource "aws_iam_user_policy_attachment" "dns_validation" {
  policy_arn = aws_iam_policy.dns_validation.arn
  user       = aws_iam_user.dns_validation.name
}

resource "tls_private_key" "reg_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.reg_private_key.private_key_pem
  email_address   = var.letsencrypt_email_address
}

resource "tls_private_key" "cert_private_key" {
  algorithm = "RSA"
}

resource "tls_cert_request" "req" {
  private_key_pem = tls_private_key.cert_private_key.private_key_pem
  dns_names       = ["*.${module.this.id}.${var.dns_zone}"]

  subject {
    common_name = "*.${module.this.id}.${var.dns_zone}"
  }
}

resource "time_sleep" "wait_for_iam_propagation" {
  # Errors can occur trying to use the IAM user immediately after creation, giving it 20 seconds
  # should be sufficient.

  depends_on = [aws_iam_access_key.dns_validation]

  create_duration = "20s"
}

resource "acme_certificate" "this" {
  account_key_pem         = acme_registration.reg.account_key_pem
  certificate_request_pem = tls_cert_request.req.cert_request_pem

  dns_challenge {
    provider = "route53"

    config = {
      AWS_ACCESS_KEY_ID     = aws_iam_access_key.dns_validation.id
      AWS_SECRET_ACCESS_KEY = aws_iam_access_key.dns_validation.secret
    }
  }

  depends_on = [time_sleep.wait_for_iam_propagation]
}
