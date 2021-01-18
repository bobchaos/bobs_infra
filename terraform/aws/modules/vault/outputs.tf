output "vault_clients_sg_id" {
  description = "ID of the security group that allows contacting Vault. Assign it to AWS assets that need Vault access."
  value       = aws_scurity_group.vault_clients.id
}