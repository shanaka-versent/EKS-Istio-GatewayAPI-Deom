# MTKC POC EKS - AWS API Gateway Foundations Module Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "api_id" {
  description = "API Gateway HTTP API ID"
  value       = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  description = "API Gateway HTTP API endpoint URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "vpc_link_id" {
  description = "VPC Link ID for private integrations"
  value       = aws_apigatewayv2_vpc_link.main.id
}

output "vpc_link_security_group_id" {
  description = "VPC Link security group ID"
  value       = aws_security_group.vpc_link.id
}

output "stage_id" {
  description = "Default stage ID"
  value       = aws_apigatewayv2_stage.default.id
}

output "custom_domain_name" {
  description = "Custom domain name (if configured)"
  value       = var.custom_domain != "" ? aws_apigatewayv2_domain_name.main[0].domain_name : null
}

output "custom_domain_target" {
  description = "Custom domain target for DNS CNAME (if configured)"
  value       = var.custom_domain != "" ? aws_apigatewayv2_domain_name.main[0].domain_name_configuration[0].target_domain_name : null
}

# Output for ArgoCD/ACK to create routes and integrations
output "ack_integration_config" {
  description = "Configuration values for ACK to create routes and integrations"
  value = {
    api_id        = aws_apigatewayv2_api.main.id
    vpc_link_id   = aws_apigatewayv2_vpc_link.main.id
    stage_name    = "$default"
    authorizer_id = var.enable_cloudfront_protection ? aws_apigatewayv2_authorizer.cloudfront[0].id : null
    note          = "Use these values in ACK Integration and Route CRDs"
  }
}

# CloudFront Protection Outputs
output "cloudfront_authorizer_id" {
  description = "Lambda Authorizer ID for CloudFront origin verification"
  value       = var.enable_cloudfront_protection ? aws_apigatewayv2_authorizer.cloudfront[0].id : null
}

output "cloudfront_authorizer_lambda_arn" {
  description = "Lambda function ARN for CloudFront authorizer"
  value       = var.enable_cloudfront_protection ? aws_lambda_function.cloudfront_authorizer[0].arn : null
}
