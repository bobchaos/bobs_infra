data "aws_region" "current" {}

data "aws_ami" "vault-server" {
  most_recent = true
  owners      = compact([data.aws_caller_identity.current.account_id, var.ami_owners])

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "name"
    values = ["vault-consul-amazon-linux-2-*"]
  }
}

data "aws_iam_policy_document" {
  statement {
    sid = "BootstrapVaultBackend"
    actions = [
      "dynamodb:DescribeLimits",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:ListTagsOfResource",
      "dynamodb:DescribeReservedCapacityOfferings",
      "dynamodb:DescribeReservedCapacity",
      "dynamodb:ListTables",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:CreateTable",
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:GetRecords",
      "dynamodb:PutItem",
      "dynamodb:Query",
      "dynamodb:UpdateItem",
      "dynamodb:Scan",
      "dynamodb:DescribeTable",
    ]
    effect    = "Allow"
    resources = [aws_dynamodb_table.bootstrap_vault_data.arn]
  }
}

data "template_file" "bootstrap_vault-ud" {
  template = file("${path.module}/templates/bootstrap_vault-ud.sh.tpl")

  vars = {
    aws_region                   = data.aws_region.current.name
    recovery_key_asm_secret_name = aws_secretsmanager_secret.bootstrap_vault_recovery_key.name
    pgp_pubkey_name              = var.pgp_pubkey_name
  }
}