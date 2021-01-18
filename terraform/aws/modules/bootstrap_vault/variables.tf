variable "tags" {
  type        = map(any)
  description = "Applied to all assets that support them, in addition to those enforced by this template."
  default     = {}
}

variable "key_name" {
  type        = string
  description = "Name of the SSH keypair to assign to instances"
}

variable "pgp_pubkey_name" {
  type        = string
  description = "Name of the file containing the PGP public key to use when encrypting the recovery key and root token. The key is expected to be baked in via Packer."
}