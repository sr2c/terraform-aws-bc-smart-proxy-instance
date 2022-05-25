module "configuration_bucket" {
  source             = "cloudposse/s3-bucket/aws"
  version            = "0.49.0"
  acl                = "private"
  enabled            = true
  versioning_enabled = false
  context            = module.this
  attributes         = ["config"]
}

data "aws_iam_policy_document" "read_configuration" {
  statement {
    effect  = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = ["${module.configuration_bucket.bucket_arn}/*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [module.configuration_bucket.bucket_arn]
  }
}

resource "aws_iam_policy" "read_configuration" {
  name   = "${module.this.id}-read-config-policy"
  policy = data.aws_iam_policy_document.read_configuration.json
}
