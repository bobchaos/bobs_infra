data "aws_subnet" "this" {
  id = random_shuffle.subnets.result[0]
}

data "aws_route53_zone" "this" {
  zone_id = var.zone_id
}

data "aws_lb" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  arn = data.aws_lb_listener.this[0].load_balancer_arn
}

data "aws_lb_listener" "this" {
  count = var.topology == "protected" || var.topology == "offloaded" ? 1 : 0
  arn = var.alb_listener_arn
}

data "template_file" "fetch_eip" {
  count    = var.topology == "public" ? 1 : 0
  template = file("${path.module}/templates/fetch_eip.sh.tpl")
  vars = {
    # This crazy looking pattern is required, otherwise you won't be able to destroy
    # Because of the way data sources are evaluated. TF12 didn't fix everything :P
    eip_alloc_id = element(concat(aws_eip.this.*.id, list("")), 0) == "" ? "We're probably destroying" : aws_eip.this.0.id
  }
}

data "template_file" "fetch_ebs_volume" {
  for_each = var.ebs_volumes != null ? var.ebs_volumes : {}
  template = file("${path.module}/templates/fetch_ebs_volume.sh.tpl")
  vars = {
    mount_point = lookup(each.value, "mount_point", "/")
    device      = lookup(each.value, "device", "/dev/sdf")
    volume_id   = aws_ebs_volume.this[each.key].id
  }
}

data "template_cloudinit_config" "this" {
  gzip          = true
  base64_encode = true

  part {
    filename = "00_init.sh"
    content_type = "text/x-shellscript"
    content = file("${path.module}/templates/init.sh.tpl")
  }

  dynamic "part" {
    # This crazy looking pattern is required, otherwise you won't be able to destroy
    # Because of the way data sources are evaluated. TF12 didn't fix everything :P
    for_each = element(concat(aws_eip.this.*.id, list("")), 0) == "" ? [] : list(aws_eip.this.0.id)
    content {
      filename     = "01_fetch_eip.sh"
      content_type = "text/x-shellscript"
      content      = data.template_file.fetch_eip.0.rendered
    }
  }

  dynamic "part" {
    # This crazy looking pattern is required, otherwise you won't be able to destroy
    # Because of the way data sources are evaluated. TF12 didn't fix everything :P
    for_each = var.ebs_volumes != null ? var.ebs_volumes : {}
    content {
      filename     = "02_${part.key}_fetch_ebs_volume.sh"
      content_type = "text/x-shellscript"
      content      = data.template_file.fetch_ebs_volume[part.key].rendered
    }
  }

  dynamic "part" {
    for_each = var.user_data != null ? list(var.user_data) : []
    content {
      filename =  "03_user_supplied_conf"
      content_type = "text/cloud-config-archive"
      content      = var.user_data
    }
  }
}
