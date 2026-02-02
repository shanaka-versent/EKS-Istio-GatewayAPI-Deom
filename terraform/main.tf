# MTKC POC EKS - Main Terraform Configuration
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# Architecture Layers:
# ===================
# Layer 1: Cloud Foundations (Terraform)
#   - VPC, Subnets, NAT Gateway, Internet Gateway
#
# Layer 2: Base EKS Cluster Setup (Terraform)
#   - EKS Cluster, Node Groups, OIDC Provider
#   - IAM Roles (Cluster, Node, LB Controller, ACK)
#   - ArgoCD Installation
#   - AWS Load Balancer Controller
#   - ALB (External Load Balancer)
#   - API Gateway Foundations (VPCLink, API, Stage)
#
# Layer 3: EKS Customizations (ArgoCD)
#   - Istio Ambient Mesh (base, istiod, cni, ztunnel)
#   - Namespaces with ambient labels
#   - Gateway and HTTPRoutes
#
# Layer 4: Application Deployment (ArgoCD)
#   - Sample Applications
#   - App-specific API Gateway routes and integrations (via ACK CRDs)

locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  cluster_name = "eks-${local.name_prefix}"
}

# ==============================================================================
# LAYER 1: CLOUD FOUNDATIONS
# ==============================================================================

# VPC Module - Network infrastructure
module "vpc" {
  source = "./modules/vpc"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  cluster_name       = local.cluster_name
  enable_nat_gateway = var.enable_nat_gateway
  tags               = var.tags
}

# ==============================================================================
# LAYER 2: BASE EKS CLUSTER SETUP
# ==============================================================================

# IAM Module - Cluster and Node roles
module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
  tags        = var.tags
}

# EKS Module - Kubernetes cluster
module "eks" {
  source = "./modules/eks"

  name_prefix        = local.name_prefix
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  cluster_role_arn   = module.iam.cluster_role_arn
  node_role_arn      = module.iam.node_role_arn

  # Use private subnets for cluster, private for nodes
  subnet_ids      = concat(module.vpc.public_subnet_ids, module.vpc.private_subnet_ids)
  node_subnet_ids = module.vpc.private_subnet_ids

  # System Node Pool
  system_node_count         = var.eks_node_count
  system_node_instance_type = var.eks_node_instance_type
  system_node_min_count     = var.system_node_min_count
  system_node_max_count     = var.system_node_max_count

  # User Node Pool (optional)
  enable_user_node_pool   = var.enable_user_node_pool
  user_node_count         = var.user_node_count
  user_node_instance_type = var.user_node_instance_type
  user_node_min_count     = var.user_node_min_count
  user_node_max_count     = var.user_node_max_count

  # Autoscaling
  enable_autoscaling = var.enable_eks_autoscaling

  # Logging
  enable_logging = var.enable_logging

  tags = var.tags
}

# IAM for AWS Load Balancer Controller (IRSA)
module "iam_lb_controller" {
  source = "./modules/iam"

  name_prefix               = "${local.name_prefix}-lb"
  create_lb_controller_role = true
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.oidc_provider_url
  tags                      = var.tags
}

# Application Load Balancer - External entry point
module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  vpc_cidr          = var.vpc_cidr
  public_subnet_ids = module.vpc.public_subnet_ids

  # HTTPS/TLS
  enable_https          = var.enable_https
  certificate_arn       = var.acm_certificate_arn
  backend_https_enabled = var.backend_https_enabled

  # Health check
  health_check_path = "/healthz/ready"

  tags = var.tags
}

# AWS Load Balancer Controller - Manages NLB/ALB in K8s
module "lb_controller" {
  source = "./modules/lb-controller"

  cluster_name       = module.eks.cluster_name
  iam_role_arn       = module.iam_lb_controller.lb_controller_role_arn
  region             = var.region
  vpc_id             = module.vpc.vpc_id
  cluster_dependency = module.eks.cluster_name
}

# ArgoCD - GitOps continuous delivery
module "argocd" {
  source = "./modules/argocd"

  argocd_version     = var.argocd_version
  service_type       = var.argocd_service_type
  insecure_mode      = true
  cluster_dependency = module.eks.cluster_name
}

# IAM for ACK API Gateway v2 Controller (IRSA)
module "iam_ack_apigatewayv2" {
  count  = var.enable_api_gateway ? 1 : 0
  source = "./modules/iam"

  name_prefix                  = "${local.name_prefix}-ack-apigw"
  create_ack_apigatewayv2_role = true
  oidc_provider_arn            = module.eks.oidc_provider_arn
  oidc_provider_url            = module.eks.oidc_provider_url
  tags                         = var.tags
}

# API Gateway Foundations - VPCLink, API, Stage
# App-specific routes/integrations are managed by ArgoCD via ACK CRDs
module "api_gateway" {
  count  = var.enable_api_gateway ? 1 : 0
  source = "./modules/api-gateway"

  name_prefix        = local.name_prefix
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = var.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids

  # Custom domain (optional)
  custom_domain   = var.api_gateway_custom_domain
  certificate_arn = var.api_gateway_certificate_arn

  # Logging
  enable_access_logs = var.enable_api_gateway_logging

  # CloudFront origin protection (when CloudFront is enabled)
  enable_cloudfront_protection = var.enable_cloudfront
  cloudfront_secret_header     = var.cloudfront_origin_secret

  tags = var.tags
}

# ==============================================================================
# PRODUCTION ENHANCEMENT: CLOUDFRONT + S3 STATIC ASSETS
# ==============================================================================
# When enabled, this creates:
# - S3 bucket for static assets (CSS, JS, images)
# - CloudFront distribution with WAF
# - Edge caching for static assets
# - Single WAF for all traffic (web and API)

# S3 Bucket for Static Assets (created first)
module "static_assets" {
  count  = var.enable_cloudfront ? 1 : 0
  source = "./modules/static-assets"

  name_prefix          = local.name_prefix
  upload_sample_assets = var.upload_sample_static_assets

  tags = var.tags
}

# CloudFront Distribution with WAF
module "cloudfront" {
  count  = var.enable_cloudfront ? 1 : 0
  source = "./modules/cloudfront"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix

  # S3 Origin for static assets
  enable_s3_origin               = true
  s3_bucket_regional_domain_name = module.static_assets[0].bucket_regional_domain_name
  s3_bucket_arn                  = module.static_assets[0].bucket_arn

  # ALB Origin for web traffic
  alb_dns_name        = module.alb.alb_dns_name
  alb_protocol_policy = var.backend_https_enabled ? "https-only" : "http-only"

  # API Gateway Origin (if enabled)
  api_gateway_domain = var.enable_api_gateway ? replace(module.api_gateway[0].api_endpoint, "https://", "") : ""

  # Origin verification header (same value for ALB and API Gateway)
  origin_verification_header = var.cloudfront_origin_secret

  # WAF Configuration
  enable_waf           = var.enable_waf
  enable_rate_limiting = var.enable_waf_rate_limiting
  rate_limit           = var.waf_rate_limit

  # TLS Configuration
  acm_certificate_arn = var.cloudfront_certificate_arn
  custom_domain       = var.cloudfront_custom_domain
  price_class         = var.cloudfront_price_class

  tags = var.tags
}

# S3 Bucket Policy for CloudFront OAC access (created after CloudFront)
resource "aws_s3_bucket_policy" "static_assets_cloudfront" {
  count  = var.enable_cloudfront ? 1 : 0
  bucket = module.static_assets[0].bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.static_assets[0].bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront[0].distribution_arn
          }
        }
      }
    ]
  })

  depends_on = [module.cloudfront]
}
