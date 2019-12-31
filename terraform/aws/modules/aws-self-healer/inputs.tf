variable "name_prefix" {
  type        = string
  description = "Used by all relevant assets for `name_prefix` on the underlying resources"
}

variable "ami_id" {
  type        = string
  description = "The AMI to spawn the self-healing instance from"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type to spawn"
}

variable "root_volume_size" {
  type        = number
  description = "Size of the root volume. Needs to be equal or greater than the one specified in the source AMI"
  default     = 8
}

variable "key_name" {
  type        = string
  description = "Name of the EC2 keypair used to authenticate to the instance"
}

variable "user_data" {
  type        = string
  description = "The user data to pass to cloud init. It will be appended to those used internally by this resource. See README.md for details"
  default     = null
}

variable "vpc_security_group_ids" {
  type        = list
  description = "A list of security groups to assign the instance"
}

variable "topology" {
  type        = string
  description = "public | private | protected | offloaded: protected is behind ALB with end-to-end SSL, offloaded is behind ALB with SSL offloading, public and private are just what they sound like."
  default     = false
}

variable "port" {
  type        = number
  description = "The port where to direct traffic. Protocol is derived from topology"
  default     = 80
}

variable "alb_listener_arn" {
  type        = string
  description = "For protected and offloaded topologies, the arn of the load balancer listener to attach to"
  default     = null
}

variable "zone_id" {
  type        = string
  description = "The Hosted Zone ID where route53 records will be created"
}

variable "tags" {
  type        = map
  description = "A map of tags to apply to all relevant assets and propagate to the instance"
  default     = {}
}

variable "vpc_subnets" {
  type        = list
  description = "A list of vpc subnets to use for the instance and it's assets. VPC ID is also derived from this value"
}

variable "ebs_volumes" {
  type = object({
    mount_point = string
    device      = string
    size        = number
  })
  description = "Custom defined EBS volumes. See README.md details"
  default     = null
}

variable "iam_policies" {
  type        = list
  description = "A list of IAM policies to add to the generated instance profile's role"
  default     = []
}

variable "depends" {
  type        = string
  description = "A _property_ of a resource or module to wait on. This hacktastic implementation is a workaround described here: https://github.com/hashicorp/terraform/issues/10462"
  default     = null
}
