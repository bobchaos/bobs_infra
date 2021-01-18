variable "name_prefix" {
  type        = string
  description = "Prepended to most asset names. Keep it short to avoid errors on some services, like a MySQL RDS instance"
  default     = "bobs"
}

variable "ami_owners" {
  type        = string
  description = "Account ID that publishes AMIs used for Consul and Vault. Assumes current account if left null"
  default     = ""
}

variable "vault_consul_cluster_tag_key" {
  type        = string
  description = "Tag by which Vault will locate it's Consul cluster, and by extension it's own cluster"
  default     = "vault_consul_cluster_identifier"
}

variable "vault_client_cidrs" {
  type        = list(string)
  description = "A list of CIDRs where non-AWS clients of Vault are expected to be. AWS assets should attach `aws_security_group.vault-clients` instead."
  default     = []
}

variable "key_name" {
  type        = string
  description = "Name of the SSH keypair to assign to instances"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to all relevant assets, in addition to default ones added by this template."
  default = {
    TF_STATE = "bobs-tfstates-bucket/bobs_infra/core"
  }
}