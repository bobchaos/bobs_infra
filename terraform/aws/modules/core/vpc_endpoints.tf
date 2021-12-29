data "aws_iam_policy_document" "dynamodb_endpoint_policy" {
  statement {
    effect    = "Deny"
    actions   = ["dynamodb:*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:sourceVpce"

      values = [data.aws_vpc_endpoint_service.dynamodb.id]
    }
  }
}

data aws_vpc_endpoint_service "dynamodb" {
  service = "dynamodb"

  filter {
    name   = "service-type"
    values = ["Gateway"]
  }
}

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.11.0"

  vpc_id             = module.main_vpc.vpc_id
  security_group_ids = [aws_security_group.https_from_priv.id]

  endpoints = {
    s3 = {
      service = "s3"
      tags    = local.tags
    },
    dynamodb = {
      service         = "dynamodb"
      service_type    = "Gateway"
      route_table_ids = flatten([module.main_vpc.intra_route_table_ids, module.main_vpc.private_route_table_ids, module.main_vpc.public_route_table_ids])
      policy          = data.aws_iam_policy_document.dynamodb_endpoint_policy.json
      tags            = local.tags
    },
    ssm = {
      service             = "ssm"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
    ssmmessages = {
      service             = "ssmmessages"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
    lambda = {
      service             = "lambda"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
    ec2messages = {
      service             = "ec2messages"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
    ec2messages = {
      service             = "autoscaling"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
    kms = {
      service             = "kms"
      private_dns_enabled = true
      subnet_ids          = module.main_vpc.private_subnets
    },
  }

  tags = local.tags
}
