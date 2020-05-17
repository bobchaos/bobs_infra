# General purpose vars
variable "name_prefix" {
  type        = string
  description = "Prepended to most asset names. Keep it short to avoid errors on some services, like a MySQL RDS instance"
  default     = "bobs"
}

variable "environment" {
  type        = string
  description = "Used in tags and some nomenclature, its intended to simplify using tools like terragrunt to duplicate the infra"
  default     = "dev"
}

# AWS provider vars
variable "primary_aws_region" {
  type        = string
  description = "the region where to spawn the bulk of the infra"
  default     = "us-east-1"
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

variable "bastion_iam_instance_profile" {
  type        = string
  description = "The instance profile to assign to the bastion. See README for minimum requirements"
  default     = "self-healer-edge-node"
}

variable "goiardi_iam_instance_profile" {
  type        = string
  description = "The instance profile to assign to Goiardi. See README for minimum requirements"
  default     = "self-healer-edge-node"
}

variable "key_name" {
  type        = string
  description = "Name of the SSH keypair to assign the instance"
}

variable "tags" {
  type        = map
  description = "tags to apply to all relevant assets"
  default     = {}
}

variable "zone_id" {
  type        = string
  description = "The zone to create r53 records in"
  default     = "Z2RQ53XGJPAY8L"
}

variable "certificate_arn" {
  type        = string
  description = "An ACM certificate ARN for use with the load balancer and protected assets"
  default     = "arn:aws:acm:us-east-1:943840344434:certificate/cf308c3c-9723-441a-bc45-7790df0f1920"
}

variable "main_db_pw" {
  type        = string
  description = "Password for the main database. Please don't commit it in git :O "
}

variable "cinc_version" {
  type        = string
  description = "The version of cinc to install on nodes that require it"
  default     = "15.6.10"
}

variable "protect_assets" {
  type        = bool
  description = "Set to true to enable protection on key persistent assets, like the main database and EBS volumes"
  default     = false
}

variable "goiardi_zero_package" {
  type        = string
  description = "Name of the package that will be retrieved from our bucket by goiardi. It must match the name of you package under `files/`"
  default     = "goiardi_server-7a30bed4d0e27978e5ef4c3d63c7dd71e374a711084305908b996577c8129dd7.tgz"
}

variable "goiardi_policy_name" {
  type        = string
  description = "Name of the policy.policyfile, excluding any extension"
  default     = "goiardi_server"
}

variable "spawn_goiardi" {
  type = bool
  default = false
}
