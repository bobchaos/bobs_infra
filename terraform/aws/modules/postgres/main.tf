# An RDS Postgres database
terraform {
  required_version = ">= 0.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.7"
    }
  }
}

locals {
  tags = merge(var.tags, {
    Terraform = "true"
  })

  asg_tags = [for k, v in local.tags : { key = k, value = v, propagate_at_launch = true }]

  db_secret_contents = jsonencode({
    username = aws_db_instance.main_postgres.username
    password = aws_db_instance.main_postgres.password
    host     = aws_db_instance.main_postgres.address
    port     = aws_db_instance.main_postgres.port
    dbname   = aws_db_instance.main_postgres.name
  })
}


# RDS postgres to support persistence for most management assets
resource "aws_security_group" "main_postgres" {
  name_prefix = var.name_prefix
  description = "TF managed security group for main postgres DB"
  vpc_id      = var.vpc_id

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
  db_subnet_group_name        = module.main_vpc.database_subnet_group
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
  # not supplying a key results in the master KMS key being used. It's fine for now
  kms_key_id              = null
  recovery_window_in_days = var.protect_assets ? 30 : 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "main_postgres_db_data" {
  secret_id     = aws_secretsmanager_secret.main_postgres_db_data.id
  secret_string = local.db_secret_contents
}