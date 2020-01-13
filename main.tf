# Create a personal lab with all sorts of devopsy things
provider "aws" {
  # Credentials expected from ENV or ~/.aws/credentials
  version = "~> 2.0"
  region  = var.primary_aws_region
}

locals {
  tags = merge({ Terraform = "true" }, var.tags)
  db_secret_contents = jsonencode({
    username = aws_db_instance.main_postgres.username
    password = aws_db_instance.main_postgres.password
    host     = aws_db_instance.main_postgres.address
    port     = aws_db_instance.main_postgres.port
    dbname   = aws_db_instance.main_postgres.name
  })
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

# An S3 bucket to hold some static assets, like chef policy artifacts
resource "aws_s3_bucket" "static_assets" {
  bucket_prefix = var.name_prefix
  force_destroy = ! var.protect_assets
  tags          = local.tags

  provisioner "local-exec" {
    command = "aws2 s3 cp ./files/${var.goiardi_zero_package} s3://${aws_s3_bucket.static_assets.id}/"
  }
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
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
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
  certificate_arn   = var.certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "There's nothing here :O You sure you got the address right?"
      status_code  = "404"
    }
  }
}

# RDS postgres to support persistence for most assets
resource "aws_security_group" "main_postgres" {
  name_prefix = var.name_prefix
  description = "TF managed security group for main postgres DB"
  vpc_id      = module.main_vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = concat(var.main_vpc_private_subnets, var.main_vpc_public_subnets)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_db_parameter_group" "main_postgres" {
  name_prefix = var.name_prefix
  family      = "postgres11"
  description = "Managed by TF for the main postgresql database"
  tags        = local.tags
}

resource "aws_db_subnet_group" "main" {
  name_prefix = var.name_prefix
  description = "Managed by TF for the main postgres DB"
  subnet_ids  = module.main_vpc.private_subnets
  tags        = local.tags
}

resource "aws_db_instance" "main_postgres" {
  identifier_prefix           = var.name_prefix
  allocated_storage           = 20
  storage_type                = "gp2"
  engine                      = "postgres"
  engine_version              = "11"
  instance_class              = "db.t3.micro"
  name                        = "postgres"
  username                    = "postgresuser"
  password                    = var.main_db_pw
  parameter_group_name        = aws_db_parameter_group.main_postgres.id
  allow_major_version_upgrade = false
  auto_minor_version_upgrade  = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  deletion_protection         = var.protect_assets
  skip_final_snapshot         = true
  multi_az                    = false
  vpc_security_group_ids      = [aws_security_group.main_postgres.id]
  tags                        = local.tags
}

# stash secrets required to bootstrap our infra; further secrets will be provided by Vault
# Once bootstrapping is complete
resource "aws_secretsmanager_secret" "main_postgres_db_data" {
  name        = "main_postgres_db_data"
  description = "The password of the main postgresql database's admin user"
  # not supplying a key results in the master KMS keyt being used. It's fine for now
  kms_key_id              = null
  recovery_window_in_days = var.protect_assets ? 30 : 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "main_postgres_db_data" {
  secret_id     = aws_secretsmanager_secret.main_postgres_db_data.id
  secret_string = local.db_secret_contents
}

# A Goiardi Server
resource aws_security_group "goiardi" {
  name_prefix = "goiardi"
  description = "Allows https ingress from main ALB"
  vpc_id      = module.main_vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.main_alb.id]
    # All RFC 1918 subnets
    cidr_blocks = concat(var.main_vpc_public_subnets, var.main_vpc_private_subnets)
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "goiardi" {
  name        = "${var.name_prefix}-goiardi"
  path        = "/terraform/"
  description = "Additional permissions required by the goiardi server to bootstrap itself"
  policy      = data.aws_iam_policy_document.bucket_and_asm.json
}

module "goiardi" {
  source = "./modules/aws-self-healer"

  name_prefix            = "${var.name_prefix}-goiardi"
  vpc_subnets            = module.main_vpc.private_subnets
  vpc_security_group_ids = [aws_security_group.goiardi.id]
  ami_id                 = data.aws_ami.centos7.id
  instance_type          = "t3a.small"
  key_name               = var.key_name
  user_data              = [data.template_file.install_goiardi.rendered]
  topology               = "offloaded"
  zone_id                = var.zone_id
  iam_policies           = [aws_iam_policy.goiardi.arn]
  alb_listener_arn       = aws_lb_listener.main_443.arn
}
