variable "name_prefix" {
  type        = string
  description = "Prepended to most asset names. Keep it short to avoid errors on some services, like a MySQL RDS instance"
}

variable "certificate_arn" {
  type        = string
  description = "An ACM certificate ARN for use with the load balancer and protected assets"
  default     = "arn:aws:acm:us-east-1:943840344434:certificate/cf308c3c-9723-441a-bc45-7790df0f1920"
}
