# ALB Module Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB zone ID (for Route53)"
  value       = aws_lb.main.zone_id
}

output "alb_name" {
  description = "ALB name"
  value       = aws_lb.main.name
}

output "target_group_http_arn" {
  description = "HTTP target group ARN"
  value       = aws_lb_target_group.istio_http.arn
}

output "target_group_https_arn" {
  description = "HTTPS target group ARN"
  value       = var.backend_https_enabled ? aws_lb_target_group.istio_https[0].arn : null
}

output "target_group_http_name" {
  description = "HTTP target group name"
  value       = aws_lb_target_group.istio_http.name
}

output "security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "http_listener_arn" {
  description = "HTTP listener ARN"
  value       = aws_lb_listener.http.arn
}

output "https_listener_arn" {
  description = "HTTPS listener ARN"
  value       = var.enable_https ? aws_lb_listener.https[0].arn : null
}

output "app_urls" {
  description = "Application URLs"
  value = {
    health = "https://${aws_lb.main.dns_name}/healthz/ready"
    app1   = "https://${aws_lb.main.dns_name}/app1"
    app2   = "https://${aws_lb.main.dns_name}/app2"
  }
}
