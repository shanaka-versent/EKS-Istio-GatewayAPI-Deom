# IAM Module Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "cluster_role_arn" {
  description = "EKS cluster IAM role ARN"
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "EKS cluster IAM role name"
  value       = aws_iam_role.cluster.name
}

output "node_role_arn" {
  description = "EKS node group IAM role ARN"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "EKS node group IAM role name"
  value       = aws_iam_role.node.name
}

output "lb_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = var.create_lb_controller_role ? aws_iam_role.lb_controller[0].arn : null
}

output "lb_controller_policy_arn" {
  description = "AWS Load Balancer Controller IAM policy ARN"
  value       = aws_iam_policy.lb_controller.arn
}

# ACK API Gateway v2 Controller outputs
output "ack_apigatewayv2_role_arn" {
  description = "ACK API Gateway v2 Controller IAM role ARN"
  value       = var.create_ack_apigatewayv2_role ? aws_iam_role.ack_apigatewayv2[0].arn : null
}

output "ack_apigatewayv2_policy_arn" {
  description = "ACK API Gateway v2 Controller IAM policy ARN"
  value       = var.create_ack_apigatewayv2_role ? aws_iam_policy.ack_apigatewayv2[0].arn : null
}
