# A Consul-backed Vault cluster should be used for "prod", but it creates a chicken-and-egg problem. Every Vault
# and Consul instances require their own unique certificates. This instance will act as a CA to bootstrap them.
# Only basic self-healing, but with a proper cluster bootstrapped losing this instance would only make the main
# cluster brittle (unable to heal) without preventing it from operating.

terraform {
  required_version = ">= 0.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }
}

locals {
  tags = merge(var.tags, {
    Terraform = "true",
  })

  asg_tags = [for k, v in local.tags : { key = k, value = v, propagate_at_launch = true }]
}
module "bootstrap_vault" {
  source  = "hashicorp/vault/aws//modules/vault-cluster"
  version = "0.14.0" # vault_module_version

  cluster_name                      = "bootstrap_vault"
  cluster_size                      = 1
  instance_type                     = "t3.micro" # Hashicorp recommends between m5.large and m5.4xlarge, but I'm cheap :P
  root_volume_size                  = 10
  root_volume_delete_on_termination = true

  instance_profile_path = "/automation/"
  cluster_tag_key       = "Vault_Cluster_ID"
  cluster_extra_tags    = local.asg_tags
  security_group_tags   = local.tags

  ami_id    = data.aws_ami.vault-server.image_id
  user_data = data.template_file.bootstrap_vault-ud.rendered

  vpc_id     = data.terraform_remote_state.core.outputs.main_vpc_id
  subnet_ids = data.terraform_remote_state.core.outputs.main_vpc_private_subnets

  # In time SSH should be disabled altogether on the instances
  # Once I have better testing mechanisms in place, like workspace support or TG
  allowed_ssh_security_group_ids = [aws_security_group.bastion.id]

  allowed_inbound_security_group_ids   = [aws_security_group.access_bootstrap_vault.id]
  allowed_inbound_security_group_count = 1
  allowed_inbound_cidr_blocks          = [data.terraform_remote_state.core.outputs.main_vpc_private_subnets_cidr_blocks]
  ssh_key_name                         = var.key_name
  # The docs still say it's an Enterprise-only feature, but that isn't true anymore; All auto-unseal methods
  # except HSM are available in the FOSS version.
  enable_auto_unseal      = true
  auto_unseal_kms_key_arn = aws_kms_key.bootstrap_vault_auto_unseal.arn

  enable_dynamo_backend = true
  dynamo_table_name     = aws_dynamodb_table.bootstrap_vault_data.name

  # The init script will try to interact with multiple resources that don't have an implicit dependency
  depends_on = [
    aws_kms_grant.auto_unseal,
    aws_kms_grant.bootstrap_vault_backend,
  ]
}

resource "aws_kms_key" "bootstrap_vault_auto_unseal" {
  description             = "Used to auto-unseal newly spawned Vault instances."
  deletion_window_in_days = 10
}

resource "aws_kms_grant" "bootstrap_vault_auto_unseal" {
  key_id            = aws_kms_key.auto_unseal.key_id
  grantee_principal = module.vault_cluster.iam_role_arn
  operations        = ["Encrypt", "Decrypt", "DescribeKey"]
}

resource "aws_security_group" "access_bootstrap_vault" {
  name_prefix = "access_bootstrap_vault"
  description = "Instance that require access to the bootstrap Vault (insgtance from the main Vault cluster and it's backing Consul cluster) must have this security group assigned."
  vpc_id      = data.terraform_remote_state.core.outputs.main_vpc_id

  egress {
    from_port          = 8200
    to_port            = 8200
    protocol           = "tcp"
    security_group_ids = [aws_security_group.access_bootstrap_vault.id]
  }
}

resource "aws_iam_policy" "bootstrap_vault_backend_access" {
  name        = "bootstrap_vault_backend_access"
  path        = "/automation/"
  description = "Allows the bootstrap Vault access to it's DynamoDB backend"

  policy = data.aws_iam_policy_document.bootstrap_vault_backend_access.json
}

resource "aws_dynamodb_table" "bootstrap_vault_data" {
  name         = "bootstrap_vault_data"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Path"
  range_key    = "Key"
  attribute = [
    {
      name = "Path"
      type = "S"
    },
    {
      name = "Key"
      type = "S"
    }
  ]
  server_side_encryption {
    kms_key_arn = aws_kms_key.bootstrap_vault.arn
    enabled     = true
  }
  tags = merge(local.tags, { Name = "bootstrap_vault_data" })
}

resource "aws_kms_key" "bootstrap_vault_backend" {
  description             = "Encrypts the bootstrap Vault's DynamoDB table storage backend."
  deletion_window_in_days = 10
}

resource "aws_kms_grant" "bootstrap_vault_backend" {
  key_id            = aws_kms_key.auto_unseal.key_id
  grantee_principal = aws_iam_role.bootstrap_vault.arn
  operations        = ["Encrypt", "Decrypt", "DescribeKey", "GenerateDataKey"]
}

resource "aws_kms_grant" "asm_for_bootstrap_vault" {
  key_id            = aws_kms_key.auto_unseal.key_id
  grantee_principal = "secretsmanager.amazonaws.com"
  operations        = ["Encrypt", "Decrypt", "DescribeKey", "GenerateDataKey"]
}

resource "aws_secretsmanager_secret" "bootstrap_vault_recovery_key" {
  name_prefix = "bootstrap_vault_recovery_key"
  description = "Contains PGP encrypted recovery key and root token for the bootstrap Vault"
  kms_key_id  = aws_kms_key.bootstrap_vault_backend.key_id
  tags        = merge(local.tags, { Name = "bootstrap_vault_recovery_key" })
}