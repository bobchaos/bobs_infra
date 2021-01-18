data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_ami" "consul-server" {
  most_recent = true
  owners      = compact([data.aws_caller_identity.current.account_id, var.ami_owners])

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "name"
    values = ["consul-amz-linux-2-*"]
  }
}

data "template_file" "consul-servers-ud" {
  template = file("${path.module}/templates/consul-server-ud.sh.tpl")

  vars = {
    cluster_tag_key   = var.vault_consul_cluster_tag_key
    cluster_tag_value = local.vault_consul_cluster_name
  }
}

data "aws_ami" "vault-server" {
  most_recent = true
  owners      = compact([data.aws_caller_identity.current.account_id, var.ami_owners])

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "name"
    values = ["vault-consul-amazon-linux-2-*"]
  }
}

data "template_file" "vault-servers-ud" {
  template = file("${path.module}/templates/vault-server-ud.sh.tpl")

  vars = {
    aws_region               = data.aws_region.current.name
    consul_cluster_tag_key   = var.vault_consul_cluster_tag_key
    consul_cluster_tag_value = local.vault_consul_cluster_name
  }
}