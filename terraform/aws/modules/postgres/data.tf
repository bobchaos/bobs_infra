# Detect AZs available to the main aws provider
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Get the latest CentOS AMI
data "aws_ami" "centos7" {
  most_recent = true
  owners      = ["679593333241"] # The marketplace
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "is-public"
    values = ["true"]
  }
  filter {
    name = "product-code"
    # Centos 8 is now available and published from a dedicated account, just need to update.
    # https://wiki.centos.org/Cloud/AWS for other CentOS product codes
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
}