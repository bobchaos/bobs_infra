# A Vault cluster; The following links were used for reference:
# https://learn.hashicorp.com/tutorials/vault/reference-architecture
# https://learn.hashicorp.com/tutorials/vault/production-hardening

locals {
  # Module versions can't be interpolated, but we feed these into templates too. This allows setting all
  # module versions in one file instead of having to hunt down references all over.
  vault_module_version      = "0.14.0" # vault_module_version
  consul_module_version     = "0.8.0"  # consul_module_version
  vault_consul_cluster_name = "${var.name_prefix}-consul-for-vault"
  tags = merge(var.tags, {
    Terraform = "true",
  })
  asg_tags = [for k, v in local.tags : { key = k, value = v, propagate_at_launch = true }]
}

resource "aws_security_group" "vault_consul_internal_access" {
  # A dummy sec group to circumvent the inability to have a module reference one of it's resources;
  # Otherwise the consul-for-vault module would have to use a broad CIDR to include all it's instances
  name_prefix = "vault_consul_internal_access"
  description = "Allows inbound https from private and intra subnets"
  vpc_id      = data.terraform_remote_state.core.outputs.main_vpc_id
}

# A dedicated Consul cluster
module "consul-for-vault" {
  source = "hashicorp/consul/aws//modules/consul-cluster"
  # We append a comment to "version" to make it easy to sed
  # Consider using Terrafile?
  version = "0.8.0" # consul_module_version

  cluster_name                      = local.vault_consul_cluster_name
  cluster_size                      = 5
  instance_type                     = "t2.micro" # Hashicorp recommends between m5.large and m5.4xlarge, but I'm cheap :P
  root_volume_size                  = 10
  root_volume_delete_on_termination = true

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = var.vault_consul_cluster_tag_key
  cluster_tag_value = local.vault_consul_cluster_name

  ami_id    = data.aws_ami.consul-server.image_id
  user_data = data.template_file.consul-servers-ud.rendered

  vpc_id     = data.terraform_remote_state.core.outputs.main_vpc_id
  subnet_ids = data.terraform_remote_state.core.outputs.main_vpc_private_subnets

  # In time SSH should be disabled altogether on the instances
  # Once I have better testing mechanisms in place, like workspace support or TG
  allowed_ssh_security_group_ids = [data.terraform_remote_state.core.outputs.bastion_sg_id]
  ssh_key_name                   = var.key_name

  # Single tenancy is recommended by Hashicorp, but too rich for my blood :P
  # tenancy = "dedicated"

  # Vault only! 
  allowed_inbound_security_group_ids = [aws_security_group.vault_consul_internal_access.id]
  additional_security_group_ids      = [aws_security_group.vault_consul_internal_access.id]
  allowed_inbound_cidr_blocks        = []

  tags = local.asg_tags
}

module "consul_iam_policies_servers" {
  source  = "hashicorp/consul/aws//modules/consul-iam-policies"
  version = "0.8.0" # consul_module_version

  iam_role_id = module.vault_cluster.iam_role_id
}

module "vaults-consul-client-sg-rules" {
  source  = "hashicorp/consul/aws//modules/consul-client-security-group-rules"
  version = "0.8.0" # consul_module_version

  security_group_id = module.vault_cluster.security_group_id

  allowed_inbound_security_group_ids   = [aws_security_group.vault_consul_internal_access.id]
  allowed_inbound_security_group_count = 1
}

# A security group that AWS assets in the same VPC can attach to get access to Vault.
# TODO: setup a private endpoint for Vault so assets in other VPCs can be treated the same way
resource "aws_security_group" "vault_clients" {
  name_prefix = "vault_clients"
  description = "Vault clients will need to attach this in order to contact Vault from outside approved CIDRs. Prioritize this over CIDRs."
  vpc_id      = data.terraform_remote_state.core.outputs.main_vpc_id

  egress {
    from_port       = 8200
    to_port         = 8200
    protocol        = "tcp"
    security_groups = module.vault_cluster.security_group_id
  }
}

resource "aws_kms_key" "vault_auto_unseal" {
  description             = "Used to auto-unseal newly spawned Vault instances."
  deletion_window_in_days = 10
}

resource "aws_kms_grant" "auto_unseal" {
  name              = "vault_auto_unseal"
  key_id            = aws_kms_key.auto_unseal.key_id
  grantee_principal = module.vault_cluster.iam_role_arn
  operations        = ["Encrypt", "Decrypt", "DescribeKey"]
}

# The Vault cluster proper
module "vault_cluster" {
  source  = "hashicorp/vault/aws//modules/vault-cluster"
  version = "0.14.0" # vault_module_version

  cluster_name                      = local.vault_consul_cluster_name
  cluster_size                      = 3
  instance_type                     = "t3.micro" # Hashicorp recommends between m5.large and m5.4xlarge, but I'm cheap :P
  root_volume_size                  = 10
  root_volume_delete_on_termination = true

  instance_profile_path = "/automation/"
  cluster_tag_key       = "Vault_Cluster_ID"
  cluster_extra_tags    = local.asg_tags
  security_group_tags   = local.tags

  ami_id    = data.aws_ami.vault-server.image_id
  user_data = data.template_file.vault-servers-ud.rendered

  vpc_id                        = data.terraform_remote_state.core.outputs.main_vpc_id
  subnet_ids                    = data.terraform_remote_state.core.outputs.main_vpc_private_subnets
  additional_security_group_ids = [aws_security_group.vault_consul_internal_access.id]

  # In time SSH should be disabled altogether on the instances
  # Once I have better testing mechanisms in place, like workspace support or TG
  allowed_ssh_security_group_ids = [data.terraform_remote_state.core.outputs.bastion_sg_id]

  allowed_inbound_security_group_ids   = [aws_security_group.vault_clients.id, aws_security_group.vault_consul_internal_access.id]
  allowed_inbound_security_group_count = 2
  allowed_inbound_cidr_blocks          = var.vault_client_cidrs
  ssh_key_name                         = var.key_name

  # The docs still say it's an Enterprise-only feature, but that isn't true anymore; All auto-unseal methods
  # except HSM are available in the FOSS version.
  enable_auto_unseal      = true
  auto_unseal_kms_key_arn = aws_kms_key.vault_auto_unseal.arn
}