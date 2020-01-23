output "asg_name" {
  value = aws_autoscaling_group.this.name
  description = "Name of the Auto Scaling Group"
}

output "iam_policy_name" {
  value = concat(aws_iam_policy.this[*].name, [""])[0]
  description = "Name of the auto-generated policy"
}

output "iam_profile_name" {
  value = aws_iam_instance_profile.this.name
  description = "Name of the auto-generated IAM instance profile"
}

output "iam_role_name" {
  value = aws_iam_role.this.name
  description = "Name of the auto-generated IAM role"
}
