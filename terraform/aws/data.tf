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
data "template_file" "setup-chef-server" {
  template = file("./templates/install_chef-server.sh.tpl")

  vars = {

  }
}

data "template_cloudinit_config" "chef-server" {
  gzip          = true
  base64_encode = true

  # The docs are a lie, the files are processed alphabetically, not
  # in the declared order, hence the numbered prefixes on filenames
  part {
    filename     = "00_setup_chef-server"
    content_type = "text/x-shellscript"
    content      = data.template_file.setup-chef-server.rendered
  }
}

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
    # CentOS 7's code. No official Centos 8 AMI published as of this writing :(
    # https://wiki.centos.org/Cloud/AWS for other CentOS product codes
    values = ["aw0evgkw8e5c1q413zgy5pjce"]
  }
}
