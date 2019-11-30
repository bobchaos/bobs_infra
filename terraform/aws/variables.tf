# General purpose vars
variable "name_prefix" {
  type = string
  description = "Prepended to most asset names. Keep it short to avoid errors on some services, like a MySQL RDS instance"
  default = "bobs"
}

variable "environment" {
  type = string
  description = "Used in tags and some nomenclature, its intended to simplify using tools like terragrunt to duplicate the infra"
  default = "dev"
}

# AWS provider vars
variable "primary_aws_region" {
  type = string
  description = "the region where to spawn the bulk of the infra"
  default = "us-east-1"
}

# vpc vars
variable "main_vpc_cidr" {
  type = string
  description = "The CIDR block to assign to the main VPC."
  default = "10.0.0.0/16"
}

variable "main_vpc_private_subnets" {
  type = list(string)
  description = "A list of CIDRs to use for private subnets."
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "main_vpc_public_subnets" {
  type = list(string)
  description = "A list of CIDRs to use for public subnets."
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}