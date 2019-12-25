# Create a personal lab with all sorts of devopsy things
provider "aws" {
  # Credentials expected from ENV or ~/.aws/credentials
  version = "~> 2.0"
  region  = var.primary_aws_region
}

locals {
  tags = merge({ Terraform = "true" }, var.tags)
}

# First we setup all networking related concerns, like a VPC and default security groups.
# External modules can be restrictive at times, but they're also quite convenient so...
module "main_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = join("-", [var.name_prefix, "main-vpc"])
  cidr = var.main_vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.main_vpc_private_subnets
  public_subnets  = var.main_vpc_public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  create_database_subnet_group = false

  tags = local.tags
}

# A self-healing bastion
resource aws_security_group "bastion" {
  name_prefix = "bastion"
  description = "Allows external ssh"
  vpc_id      = module.main_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "bastion" {
  source = "./modules/aws-self-healer"

  name_prefix            = "${var.name_prefix}-bastion"
  vpc_subnets            = module.main_vpc.public_subnets
  vpc_security_group_ids = [aws_security_group.bastion.id]
  ami_id                 = data.aws_ami.centos7.id
  instance_type          = "t3a.nano"
  iam_instance_profile   = var.bastion_iam_instance_profile
  key_name               = var.key_name
  user_data              = null
  topology               = "public"
  zone_id                = var.zone_id
}

# The main Application Load Balancer that will shield our instances and provide ssl offloading
resource aws_security_group "main_alb" {
  name_prefix = "${var.name_prefix}-main-alb"
  description = "Allows traffic from internet to LB, and from LB to destination target groups"
  vpc_id      = module.main_vpc.vpc_id
  # Rules not included. Using external rules allows instances to add themselves as needed
}

resource "aws_security_group_rule" "main_alb_443" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main_alb.id
}

resource aws_lb "main" {
  name_prefix        = var.name_prefix
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.main_alb.id]
  subnets            = module.main_vpc.public_subnets
  tags               = local.tags
}

resource "aws_lb_listener" "main_443" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"
  default_action {
    type             = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "There's nothing here :O You sure you got the address right?"
      status_code = "404"
    }
  }
}

# A Goiardi Server
resource aws_security_group "goiardi" {
  name_prefix = "goiardi"
  description = "Allows https ingress"
  vpc_id      = module.main_vpc.vpc_id

  ingress {
    # TLS (change to whatever ports you need)
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    # Please restrict your ingress to only necessary IPs and ports.
    # Opening to 0.0.0.0/0 can lead to security vulnerabilities.
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
