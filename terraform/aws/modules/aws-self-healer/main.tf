# Creates a self-healing instance by leveraging autoscaling groups
locals {
  use_ebs = var.ebs_volumes == null ? false : true
  vpc_id  = data.aws_subnet.this.vpc_id
  domain  = replace(data.aws_route53_zone.this.name, "/\\.$/", "")
}

# A dirty hack to implement dependencies on resources for this module
# This is sometimes required to allow data used by Chef/Cloud-init to populate
resource "null_resource" "this" {
  count = var.depends != null ? 1 : 0
  triggers = {
    dependency_id = var.depends
  }
}

# IAM policy handling
resource "aws_iam_policy" "this" {
  count       = var.ebs_volumes != null || var.topology == "public" ? 1 : 0
  name        = "${var.name_prefix}-instance-policy"
  path        = "/"
  description = "Generated by Terraform for ${var.name_prefix}"
  policy      = data.aws_iam_policy_document.this_instance.json
}

resource "aws_iam_role" "this" {
  name               = "${var.name_prefix}-role"
  path               = "/terraform/instances/"
  assume_role_policy = data.aws_iam_policy_document.this_role.json
}

resource "aws_iam_role_policy_attachment" "this" {
  count      = var.ebs_volumes != null || var.topology == "public" ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this[0].arn
}

resource "aws_iam_role_policy_attachment" "user_defined" {
  count      = length(var.iam_policies)
  role       = aws_iam_role.this.name
  policy_arn = element(var.iam_policies, count.index)
}

resource "aws_iam_instance_profile" "this" {
  path = "/terraform/"
  role = aws_iam_role.this.name
}

# The ASG proper
resource "aws_launch_template" "this" {
  name_prefix   = var.name_prefix
  description   = format("Terraform generated template for %s self-healing instance", var.name_prefix)
  image_id      = var.ami_id
  instance_type = var.instance_type
  iam_instance_profile {
    name = aws_iam_instance_profile.this.name
  }
  block_device_mappings {
    device_name = data.aws_ami.this.root_device_name
    ebs {
      # Root volumes should contain only system and ephemeral data.
      # State should be handled by databases or mounted ebs volumes, etc.
      delete_on_termination = true
      volume_size           = var.root_volume_size
    }
  }
  key_name               = var.key_name
  vpc_security_group_ids = var.vpc_security_group_ids
  tags                   = var.tags
  user_data              = data.template_cloudinit_config.this.rendered
}

resource "aws_autoscaling_group" "this" {
  # if using EBS, we need a static zone assignement
  vpc_zone_identifier = local.use_ebs ? random_shuffle.subnets.result : var.vpc_subnets
  desired_capacity    = 1
  max_size            = 1
  min_size            = 1
  target_group_arns   = var.topology == "protected" || var.topology == "offloaded" ? aws_lb_target_group.this[*].arn : null
  launch_template {
    id      = aws_launch_template.this.id
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
  input        = var.vpc_subnets
  result_count = 1
}

resource "aws_ebs_volume" "this" {
  # OMG I love TF 12
  for_each = var.ebs_volumes != null ? var.ebs_volumes : {}

  availability_zone = data.aws_subnet.this.availability_zone
  size              = lookup(each.value, "size", "volume size not provided")
  tags              = var.tags
}

# An EIP if this instance is internet facing. Do note there is no attachement for the
# same reason as the EBS volume.
resource "aws_eip" "this" {
  count = var.topology == "public" ? 1 : 0
  vpc   = true
  tags  = var.tags
}

# A dns record; Load balanced instances use alias records, others use plain A/AAAA
resource "aws_route53_record" "thisa" {
  # Private instances cannot have DNS assigned during terraform run since it won't exist
  # until the ASG's done it's part. Cloud-init can still accomodate such needs
  count   = var.topology == "private" ? 0 : 1
  zone_id = var.zone_id
  name    = var.name_prefix
  type    = "A"
  ttl     = var.topology == "protected" || var.topology == "offloaded" ? null : "300"
  records = var.topology == "protected" || var.topology == "offloaded" ? null : [aws_eip.this[0].public_ip]

  dynamic "alias" {
    for_each = var.topology == "protected" || var.topology == "offloaded" ? ["alias"] : []
    content {
      name                   = data.aws_lb.this[0].dns_name
      zone_id                = data.aws_lb.this[0].zone_id
      evaluate_target_health = false
    }
  }
}

# Everything that follows is used to enable the "protected" and "offloaded" topology
resource "aws_lb_target_group" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  # Target groups have a mx prefix of 6 characters
  name_prefix = substr(var.name_prefix, 0, 5)
  port        = var.port
  protocol    = var.topology == "protected" ? "HTTPS" : "HTTP"
  vpc_id      = local.vpc_id
}

# Host based routing for protected instances
resource "aws_lb_listener_rule" "this" {
  count        = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
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
