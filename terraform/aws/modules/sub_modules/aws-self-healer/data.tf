data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_subnet" "this" {
  id = random_shuffle.subnets.result[0]
}

data "aws_route53_zone" "this" {
  zone_id = var.zone_id
}

data "aws_lb" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  arn   = data.aws_lb_listener.this[0].load_balancer_arn
}

data "aws_lb_listener" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  arn   = var.alb_listener_arn
}

data "aws_ami" "this" {
  owners = ["self", "aws-marketplace"]
  filter {
    name   = "image-id"
    values = [var.ami_id]
  }
}

data "aws_iam_policy_document" "this_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "this_instance" {
  dynamic "statement" {
    for_each = var.topology == "public" ? aws_eip.this[*].id : []
    content {
      sid       = "${replace(var.name_prefix, "-", "")}Eip"
      effect    = "Allow"
      actions   = ["ec2:DescribeAddresses", "ec2:AssociateAddress"]
      # for reasons beyond me, the aws_eip resource doesn't output the ARN.
      resources = ["arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:elastic-ip/${statement.value}"]
    }
  }
  dynamic "statement" {
    for_each = var.ebs_volumes != null ? aws_ebs_volume.this[*].arn : []
    content {
      sid       = "${replace(var.name_prefix, "-", "")}Ebs"
      effect    = "Allow"
      actions   = ["ec2:DescribeVolumeStatus", "ec2:DescribeVolumes", "ec2:AttachVolume"]
      resources = statement.value
    }
  }
}

data "template_cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "00_init.sh"
    content_type = "text/x-shellscript"
    content      = file("${path.module}/templates/init.sh.tpl")
  }

  dynamic "part" {
    for_each = var.topology == "public" ? aws_eip.this[*].id : []
    content {
      filename     = "01_fetch_eip_${part.value}.sh"
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/fetch_eip.sh.tpl", {
        eip_alloc_id = part.value
      })
    }
  }

  dynamic "part" {
    for_each = var.ebs_volumes != null ? var.ebs_volumes : {}
    content {
      filename     = "02_${part.key}_fetch_ebs_volume.sh"
      content_type = "text/x-shellscript"
      content      = templatefile("${path.module}/templates/fetch_ebs_volume.sh.tpl", {
        mount_point = lookup(part.value, "mount_point", "/")
        device      = lookup(part.value, "device", "/dev/sdf")
        volume_id   = aws_ebs_volume.this[part.key].id
      })
    }
  }

  dynamic "part" {
    for_each = var.user_data != null ? ["user_provided"] : []
    content {
      filename     = "03_user_supplied_conf"
      content_type = "text/cloud-config-archive"
      content      = var.user_data
    }
  }
}