# Creates a self-healing instance by leveraging autoscaling groups
locals {
  use_ebs = var.ebs_volumes == null ? false : true
  vpc_id = data.aws_subnet.this.vpc_id
  domain = replace(data.aws_route53_zone.this.name, "/\\.$/", "")
}

# The ASG proper
resource "aws_launch_template" "this" {
  name_prefix = var.name_prefix
  description = format("Terraform generated template for %s self-healing instance", var.name_prefix)
  image_id = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile { 
    name = var.iam_instance_profile
  }
  key_name = var.key_name
  vpc_security_group_ids = var.vpc_security_group_ids
  tags = var.tags
  user_data = data.template_cloudinit_config.this.rendered
}

resource "aws_autoscaling_group" "this" {
  # if using EBS, we need a static zone assignement
  vpc_zone_identifier = local.use_ebs ? random_shuffle.subnets.result : var.vpc_subnets
  desired_capacity = 1
  max_size = 1
  min_size = 1
  target_group_arns = var.topology == "protected" || var.topology == "offloaded" ? aws_lb_target_group.this[0].arn : null
  launch_template {
    id = aws_launch_template.this.id
    version = "$Latest"
  }
}

# Optional EBS volumes. Note there is no attachement so as to avoid race conditions 
# with create_before_destroy lifecycle. The instances will setup the attachements
# themselves using cloud-init. See here for the full explanation: 
# https://docs.aws.amazon.com/autoscaling/ec2/userguide/healthcheck.html#replace-unhealthy-instance

# EBS volumes _must_ be spawned in the same AZ as the instance they will be attached to
# so we force the selection of a specific AZ. This unfortunately prevents instances spawned
# by this module with EBS volume from travelling to another AZ should one fail.
resource "random_shuffle" "subnets" {
  input = var.vpc_subnets
  result_count = 1
}

resource "aws_ebs_volume" "this" {
  # OMG I love TF 12
  for_each = var.ebs_volumes != null ? var.ebs_volumes : {}

  availability_zone = data.aws_subnet.this.availability_zone
  size = lookup(each.value, "size", "volume size not provided")
  tags = var.tags
}

# An EIP if this instance is internet facing. Do note there is no attachement for the
# same reason as the EBS volume.
resource "aws_eip" "this" {
  count = var.topology == "public" ? 1 : 0
  vpc = true
  tags = var.tags
}

# Everything that follows is used to enable the "protected" and "offloaded" topology
resource "aws_lb_target_group" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  name_prefix     = var.name_prefix
  port     = var.port
  protocol = var.topology == "protected" ? "HTTPS" : "HTTP"
  vpc_id   = local.vpc_id
}

# Host based routing for protected instances
resource "aws_lb_listener_rule" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  listener_arn = var.alb_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[0].arn
  }

  condition {
    host_header {
      values = ["${var.name_prefix}.${local.domain}"]
    }
  }
}
