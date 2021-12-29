# General purpose vars
variable "name_prefix" {
  type        = string
  description = "Prepended to most asset names. Keep it short to avoid errors on some services, like a MySQL RDS instance"
}

variable "environment" {
  type        = string
  description = "Used in tags and some nomenclature, its intended to simplify using tools like terragrunt to duplicate the infra"
  default     = "dev"
}

# vpc vars
variable "main_vpc_cidr" {
  type        = string
  description = "The CIDR block to assign to the main VPC."
  default     = "10.0.0.0/16"
}

variable "main_vpc_private_subnets" {
  type        = list(string)
  description = "A list of CIDRs to use for private subnets."
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "main_vpc_public_subnets" {
  type        = list(string)
  description = "A list of CIDRs to use for public subnets."
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "main_vpc_intra_subnets" {
  type        = list(string)
  description = "A list of CIDRs to use for intra subnets (no IGW)."
  default     = ["10.0.51.0/24", "10.0.52.0/24", "10.0.53.0/24"]
}

variable "main_vpc_database_subnets" {
  type        = list(string)
  description = "A list of CIDRs to use for database subnets."
  default     = ["10.0.151.0/24", "10.0.152.0/24", "10.0.153.0/24"]
}

variable "bastion_iam_instance_profile" {
  type        = string
  description = "The instance profile to assign to the bastion. See README for minimum requirements"
  default     = "self-healer-edge-node"
}

variable "key_name" {
  type        = string
  description = "Name of the SSH keypair to assign to instances"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to all relevant assets, in addition to default ones added by this template."
  default     = {}
}

variable "zone_id" {
  type        = string
  description = "The zone to create r53 records in"
}

variable "certificate_arn" {
  type        = string
  description = "An ACM certificate ARN for use with the load balancer and protected assets"
}

# variable "main_db_pw" {
#   type        = string
#   description = "Password for the main database. Please don't commit it in git :O "
# }

# variable "cinc_version" {
#   type        = string
#   description = "The version of cinc to install on nodes that require it"
#   default     = "15.6.10"
# }

variable "protect_assets" {
  type        = bool
  description = "Set to true to enable protection on key persistent assets, like the main database and EBS volumes"
  default     = false
}

variable "ami_owners" {
  type        = string
  description = "ID of the account that publishes your Vault AMIs. Assumes current account if left null."
  default     = ""
}