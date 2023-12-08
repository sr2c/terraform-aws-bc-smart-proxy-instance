locals {
  trimmed_dns_zone = trimsuffix(var.dns_zone, ".")
  group_name       = coalesce(module.this.tenant, "default")
}

resource "tls_private_key" "provisioner_ssh" {
  algorithm = "RSA"
}

resource "aws_key_pair" "provisioner" {
  key_name   = module.this.id
  public_key = tls_private_key.provisioner_ssh.public_key_openssh
}

module "conf_log" {
  source              = "sr2c/ec2-conf-log/aws"
  version             = "0.0.4"
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

resource "aws_security_group" "instance" {
  name        = module.this.id
  description = "Smart proxy security group for ${module.this.id}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "this" {
  instance = aws_instance.this.id
}

resource "aws_instance" "this" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  subnet_id = data.aws_subnet.default.id

  associate_public_ip_address = true
  disable_api_termination     = var.disable_api_termination

  key_name             = module.this.id
  iam_instance_profile = module.conf_log.instance_profile_name
  user_data_base64     = data.cloudinit_config.this.rendered

  security_groups = [
    aws_security_group.instance.id
  ]

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait",
      "sleep 30" # Give tor and obfs4proxy time to generate keys and state
    ]
  }

  connection {
    host        = aws_instance.this.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.provisioner_ssh.private_key_openssh
    timeout     = "5m"
  }

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "this" {
  name = local.trimmed_dns_zone
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.id
  name    = "*.${local.group_name}.smart"
  type    = "A"
  ttl     = 180

  records = [
    aws_eip.this.public_ip
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
              "_acme-challenge.${local.group_name}.smart.${local.trimmed_dns_zone}"
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
  dns_names       = ["*.${local.group_name}.smart.${local.trimmed_dns_zone}"]

  subject {
    common_name = "*.${local.group_name}.smart.${local.trimmed_dns_zone}"
  }
}

resource "time_sleep" "wait_for_iam_propagation" {
  # Errors can occur trying to use the IAM user immediately after creation, giving it 20 seconds
  # should be sufficient. Re-run the creation delay if any of the IAM resources change.

  depends_on = [aws_iam_access_key.dns_validation]

  triggers = {
    iam_policy_attachment = aws_iam_user_policy_attachment.dns_validation.id
    iam_policy            = aws_iam_policy.dns_validation.policy
    iam_user              = aws_iam_user.dns_validation.id
    iam_access_key        = aws_iam_access_key.dns_validation.id
  }

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
