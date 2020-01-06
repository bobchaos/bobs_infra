# Detect AZs available in var.primary_aws_region
data "aws_availability_zones" "available" {
  state = "available"
}

# User data for the Chef server. Note there's no cloud-config
# extra scripts are passed as-is. Shell only
data "template_file" "install_goiardi" {
  template = file("./templates/zero_package.sh.tpl")

  vars = {
    cinc_version = "15.6.10"
    bucket_name  = aws_s3_bucket.static_assets.id
    zero_package = var.goiardi_zero_package
    policy_name  = var.goiardi_policy_name
  }
}

# Get the latest CentOS AMI
data "aws_ami" "centos7" {
  most_recent = true
  owners      = ["679593333241"] # The marketplace
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "is-public"
    values = ["true"]
  }
  filter {
    name = "product-code"
    # CentOS 7's code. No official Centos 8 AMI published as of this writing :(
    # https://wiki.centos.org/Cloud/AWS for other CentOS product codes
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
}

# IAM Policy documents
data "aws_iam_policy_document" "bucket_and_asm" {
  statement {
    actions   = ["s3:ListBucket"]
    sid       = "${replace(var.name_prefix, "-", "")}BucketList"
    effect    = "Allow"
    resources = [aws_s3_bucket.static_assets.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    sid       = "${replace(var.name_prefix, "-", "")}BucketRead"
    effect    = "Allow"
    resources = ["${aws_s3_bucket.static_assets.arn}/*"]
  }
  statement {
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    sid       = "${replace(var.name_prefix, "-", "")}ASM"
    effect    = "Allow"
    resources = [aws_secretsmanager_secret.main_postgres_db_data.arn]
  }
}

