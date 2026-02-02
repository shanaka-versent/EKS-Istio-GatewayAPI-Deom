# MTKC POC EKS - Terraform Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

# ==============================================================================
# LAYER 1: CLOUD FOUNDATIONS
# ==============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

# ==============================================================================
# LAYER 2: BASE EKS CLUSTER SETUP
# ==============================================================================

# EKS Cluster
output "eks_cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS Cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_get_credentials_command" {
  description = "Command to get EKS credentials"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "eks_oidc_issuer_url" {
  description = "EKS OIDC issuer URL for workload identity"
  value       = module.eks.oidc_issuer_url
}

# AWS Load Balancer Controller
output "lb_controller_role_arn" {
  description = "AWS Load Balancer Controller IAM role ARN"
  value       = module.iam_lb_controller.lb_controller_role_arn
}

# ALB Outputs
output "alb_name" {
  description = "Application Load Balancer name"
  value       = module.alb.alb_name
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_target_group_arn" {
  description = "ALB target group ARN (for backend pool update)"
  value       = var.backend_https_enabled ? module.alb.target_group_https_arn : module.alb.target_group_http_arn
}

# ArgoCD Outputs
output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = module.argocd.namespace
}

output "argocd_admin_password" {
  description = "ArgoCD admin password (retrieve with: terraform output -raw argocd_admin_password)"
  value       = module.argocd.admin_password
  sensitive   = true
}

output "argocd_url" {
  description = "ArgoCD URL (get LoadBalancer IP with: kubectl get svc -n argocd argocd-server)"
  value       = "https://<argocd-server-loadbalancer-ip>"
}

# ACK API Gateway Controller
output "api_gateway_enabled" {
  description = "Whether API Gateway is enabled"
  value       = var.enable_api_gateway
}

output "ack_apigatewayv2_role_arn" {
  description = "ACK API Gateway v2 Controller IAM role ARN (for IRSA)"
  value       = var.enable_api_gateway ? module.iam_ack_apigatewayv2[0].ack_apigatewayv2_role_arn : null
}

# API Gateway Foundations (when enabled)
output "api_gateway_endpoint" {
  description = "API Gateway HTTP API endpoint URL"
  value       = var.enable_api_gateway ? module.api_gateway[0].api_endpoint : null
}

output "api_gateway_id" {
  description = "API Gateway HTTP API ID"
  value       = var.enable_api_gateway ? module.api_gateway[0].api_id : null
}

output "api_gateway_vpc_link_id" {
  description = "VPC Link ID for private integrations"
  value       = var.enable_api_gateway ? module.api_gateway[0].vpc_link_id : null
}

# Configuration for ACK to create app-specific routes/integrations
output "ack_integration_config" {
  description = "Configuration for ACK to create routes and integrations (Layer 4)"
  value = var.enable_api_gateway ? {
    api_id      = module.api_gateway[0].api_id
    vpc_link_id = module.api_gateway[0].vpc_link_id
    api_endpoint = module.api_gateway[0].api_endpoint
    note        = "Use these values in ACK Integration and Route CRDs managed by ArgoCD"
  } : null
}

# ==============================================================================
# APPLICATION URLS
# ==============================================================================

output "app_urls_https" {
  description = "HTTPS URLs for applications"
  value = var.enable_https ? {
    health = "https://${module.alb.alb_dns_name}/healthz/ready"
    app1   = "https://${module.alb.alb_dns_name}/app1"
    app2   = "https://${module.alb.alb_dns_name}/app2"
  } : null
}

output "app_urls_http" {
  description = "HTTP URLs for applications (redirects to HTTPS when enabled)"
  value = {
    health = "http://${module.alb.alb_dns_name}/healthz/ready"
    app1   = "http://${module.alb.alb_dns_name}/app1"
    app2   = "http://${module.alb.alb_dns_name}/app2"
  }
}

output "https_enabled" {
  description = "Whether HTTPS is enabled"
  value       = var.enable_https
}

# ==============================================================================
# HELPER COMMANDS
# ==============================================================================

output "update_target_group_command" {
  description = "Command to register Internal NLB IP with ALB target group"
  value       = "aws elbv2 register-targets --target-group-arn ${var.backend_https_enabled ? module.alb.target_group_https_arn : module.alb.target_group_http_arn} --targets Id=<INTERNAL_NLB_IP>"
}

output "ack_helm_install_command" {
  description = "Helm command to install ACK API Gateway v2 Controller (managed by ArgoCD)"
  value       = var.enable_api_gateway ? <<-EOT
    # ACK Controller is installed via ArgoCD
    # Update argocd/apps/09-ack-apigatewayv2.yaml with:
    #   serviceAccount.annotations.eks.amazonaws.com/role-arn: ${module.iam_ack_apigatewayv2[0].ack_apigatewayv2_role_arn}
  EOT
  : null
}

# ==============================================================================
# PRODUCTION ENHANCEMENT: CLOUDFRONT + S3 STATIC ASSETS
# ==============================================================================

output "cloudfront_enabled" {
  description = "Whether CloudFront is enabled"
  value       = var.enable_cloudfront
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = var.enable_cloudfront ? module.cloudfront[0].distribution_domain_name : null
}

output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = var.enable_cloudfront ? "https://${module.cloudfront[0].distribution_domain_name}" : null
}

output "static_assets_bucket" {
  description = "S3 bucket for static assets"
  value       = var.enable_cloudfront ? module.static_assets[0].bucket_id : null
}

output "static_assets_url" {
  description = "URL for static assets via CloudFront"
  value       = var.enable_cloudfront ? "https://${module.cloudfront[0].distribution_domain_name}/static/" : null
}

output "waf_web_acl_id" {
  description = "WAF Web ACL ID"
  value       = var.enable_cloudfront && var.enable_waf ? module.cloudfront[0].waf_web_acl_id : null
}

# CloudFront Application URLs (when enabled)
output "cloudfront_app_urls" {
  description = "Application URLs via CloudFront (when enabled)"
  value = var.enable_cloudfront ? {
    demo     = "https://${module.cloudfront[0].distribution_domain_name}/demo"
    app1     = "https://${module.cloudfront[0].distribution_domain_name}/app1"
    app2     = "https://${module.cloudfront[0].distribution_domain_name}/app2"
    health   = "https://${module.cloudfront[0].distribution_domain_name}/healthz/ready"
    static   = "https://${module.cloudfront[0].distribution_domain_name}/static/"
    api      = var.enable_api_gateway ? "https://${module.cloudfront[0].distribution_domain_name}/api/" : null
  } : null
}
