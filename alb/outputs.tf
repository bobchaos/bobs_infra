output "main_alb_sg_id" {
  value       = aws_security_group.main_alb.id
  description = "ID of the main ALB's security group"
}

output "main_alb_arn" {
  value = aws_lb.main.arn
  description = "ARN of the main load balancer"
}

output "main_alb_listener_arn" {
  value = aws_lb_listener.main_443.arn
  description = "ARN of the main ALB's HTTPS listener"
}
