resource aws_security_group "goiardi" {
  count = var.spawn_module ? 1 : 0
  name_prefix = "goiardi"
  description = "Allows https ingress from main ALB"
  vpc_id = var.main_vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    # security_groups = [aws_security_group.main_alb.id]
    security_groups = var.main_alb_sg_id
    # All RFC 1918 subnets
    cidr_blocks = concat(var.main_vpc_public_subnets, var.main_vpc_private_subnets)
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = var.bastion_sg_id
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_policy" "goiardi" {
  count = var.spawn_module ? 1 : 0
  name        = "${var.name_prefix}-goiardi"
  path        = "/terraform/"
  description = "Additional permissions required by the goiardi server to bootstrap itself"
  policy      = var.iam_policy_json
}

module "goiardi" {
  source = var.spawn_module ? "../../aws-self-healer" : "../../dummy"

  name_prefix            = "${var.name_prefix}-goiardi"
  vpc_subnets            = var.main_vpc_private_subnets
  vpc_security_group_ids = [aws_security_group.goiardi.id]
  ami_id                 = var.instance_ami_id
  instance_type          = "t3a.small"
  key_name               = var.key_name
  user_data              = var.user_Data
  topology               = "offloaded"
  zone_id                = var.zone_id
  iam_policies           = [aws_iam_policy.goiardi.arn]
  alb_listener_arn       = var.main_alb_listener_arn
}
