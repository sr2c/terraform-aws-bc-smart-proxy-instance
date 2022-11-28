module "instance_profile_label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["profile"]

  context = module.this.context
}

data "aws_iam_policy_document" "assume_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "smart_proxy" {
  name               = "${module.this.id}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_policy.json
  tags               = module.instance_profile_label.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.smart_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.smart_proxy.name
  policy_arn = aws_iam_policy.read_configuration.arn
}

resource "aws_iam_instance_profile" "smart_proxy" {
  name = "${module.this.id}-profile"
  role = aws_iam_role.smart_proxy.name
}