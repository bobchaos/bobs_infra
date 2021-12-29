output "main_vpc_id" {
  description = "ID of the main VPC"
  value       = module.main_vpc.vpc_id
}

output "main_vpc_public_subnets" {
  description = "Public subnet IDs for the main VPC"
  value       = module.main_vpc.public_subnets
}

output "main_vpc_private_subnets" {
  description = "Private subnet IDs for the main VPC"
  value       = module.main_vpc.public_subnets
}

output "main_vpc_intra_subnets" {
  description = "Private intra subnets for the main VPC"
  value       = module.main_vpc.intra_subnets
}

output "main_vpc_database_subnets" {
  description = "Dedicated database subnets for the main VPC"
  value       = module.main_vpc.database_subnets
}

output "bastion_sg_id" {
  description = "ID of the Bastion instance's security group"
  value       = aws_security_group.bastion.id
}

output "access_bootstrap_vault_sg_id" {
  description = "ID of the security group that grants access to the bootstrap Vault"
  value       = aws_security_group.access_bootstrap_vault.id
}