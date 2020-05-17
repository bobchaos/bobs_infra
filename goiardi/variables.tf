variable "main_vpc_id" {
  type = string
  description = "ID of the VPC to use for the goiardi server"
}

variable "main_alb_sg_id" {
  type = string
  description = "ID of the main ALB's security group"
}

variable "main_vpc_public_subnets" {
  type = string
  description = "ID of the public subnets associated with the main VPC"
}

variable "main_vpc_public_subnets" {
  type = string
  description = "ID of the private subnets associated with the main VPC"
}

variable "bastion_sg_id" {
  type = string
  description = "ID of the bastion's security group"
}

variable "name_prefix" {
  type = string
  description = "A prefix to apply to most asset's names"
}

variable "instance_ami_id" {
  type = string
  description = "The ID of an AMI to use when spawning the Goiardi server"
}

variable "key_name" {
  type = string
  description = "Name of an AWS keypair to use for the Goiradi Server"
}

variable "zone_id" {
  type = string
  description = "ID of an AWS Route53 zone to create DNS records in"
}

variable "main_alb_listener_arn" {
  type = string
  description = "ARN of the main alb's HTTPS listener"
}

variable "iam_policy_json" {
  type = string
  description = "JSON formatted IAM policy to grant to the Goiardi Server's instance profile"
}

variable "user_data" {
  type = string
  description = "user_data to pass to the Goiardi server"
}
