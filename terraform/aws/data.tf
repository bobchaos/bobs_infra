# Detect AZs available in var.primary_aws_region
data "aws_availability_zones" "available" {
  state = "available"
}

# look under ${path.module}/templates} for some reusable cloud-init
# part script, including:
# - awscli.sh : installs AWS cli v2. Required by most other scripts.
# - conf_manager.sh : installs cinc-client or chef-client.
# - zero_package.sh : runs a standalone, arbitrary chef-zero package,
#   useful to install addional prerequisites
# - fetch_eip.sh : have an instance fetch it's own EIP. Used
#   internally by the aws-self-healer module.
# - fetch_ebs.sh : have an instance fetch and mount its own EBS vol.
#   Used internally by the aws-self-healer module
# - bootstrap_conf.sh : bootstraps the instance with cinc against
#   goiardi, or with Chef Infra Client VS Chef Infra Server
# - hart_processor.sh : sets up Biome or Chef Habitat

# User data for the Chef server
data "template_file" "chef-server_awscli" {
  template = file("${path.module}/templates/awscli.sh.tpl")

  vars {
    
  }
}

data "template_file" "chef-server_awscli" {
  template = file("${path.module}/templates/install_chef-server.sh.tpl")

  vars {

  }
}

data "template_cloudinit_config" "chef-server" {
  gzip          = true
  base64_encode = true

  # The docs are a lie, the files are processed alphabetically, not
  # in the declared order, hence the numbered prefixes on filenames
  part {
    filename = "00_awscli.sh"
    content_type = "text/cloud-config"
    content = data.template_file.chef-server_prereqs.rendered
  }

  part {
    filename = "01_install_chef-server"
    content_type = "text/x-shellscript"
    content = data.template_file.chef-server_prereqs.rendered
  }
}
