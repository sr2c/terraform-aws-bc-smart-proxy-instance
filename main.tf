
data "cloudinit_config" "this" {
  base64_encode = true
  gzip          = true

  part {
    content = templatefile("${path.module}/templates/user_data.yaml", {
      configure_script = jsonencode(templatefile("${path.module}/templates/configure.sh",
      { bucket_name = module.configuration_bucket.bucket_id })),
      crontab     = jsonencode(file("${path.module}/templates/cron")),
      certificate = jsonencode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"),
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
  instance_profile            = aws_iam_instance_profile.smart_proxy.name
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
}
