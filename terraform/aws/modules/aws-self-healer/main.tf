# Creates a self-healing instance by leveraging autoscaling groups
locals {
  use_ebs = length(var.ebs_volumes) == 0 ? false : true
}
# The ASG proper
resource "aws_launch_template" "this" {
  name_prefix = var.name_prefix
  description = format("Terraform generated template for %s self-healer", var.name_prefix)
  disable_api_termination = var.instance_protection
  image_id = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile = var.iam_profile
  key_name = var.key_name
  vpc_security_group_ids = aws_security_group.this.id
  tags = var.tags
  user_data = var.user_data
}

resource "aws_autoscaling_group" "this" {
  availability_zones = local.use_ebs ? random_shuffle.az.result : data.availability_zones.available.names
  desired_capacity = 1
  max_size = 1
  min_size = 1

  launch_template {
    id = "${aws_launch_template.this.id}"
    version = "$Latest"
  }
}

# Optional EBS volumes. Note there is no attachement so as to avoid
# race conditions with create_before_destroy lifecycle. The instances
# will setup the attachements themselves using cloud-init

# EBS volumes _must_ be spawned in the same AZ as the instance they will be attached to
# so we force the selection of a specific AZ. This unfortunately prevents instances spawned
# by this module with EBS volume from travelling to another AZ should one fail.
resource "random_shuffle" "az" {
  count = local.use_ebs ? 1 : 0
  input = var.azs
  result_count = 1
}

resource "aws_ebs_volume" "this" {
  # OMG I love TF 12
  for_each = { var.ebs_volumes }

  availability_zone = random_shuffle.az.result
  size = lookup(each.value, size, "volume size not provided")
  tags = var.tags
}
