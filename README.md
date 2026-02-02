# AWS EKS Reference Architecture - Kubernetes Gateway API with Istio Ambient

**Author:** Shanaka Jayasundera - shanakaj@gmail.com

This is the **reference architecture** branch demonstrating a production-ready Kubernetes architecture on AWS EKS with:
- **Kubernetes Gateway API** (not Ingress)
- **Istio Ambient Mesh** (no sidecars)
- **CloudFront + WAF** for edge security
- **S3** for static assets with CDN caching
- **AWS ALB** + **Internal NLB** for web traffic
- **AWS API Gateway** with VPC Link for API traffic
- **ACK** (AWS Controllers for Kubernetes) for API route management
- **ArgoCD** for GitOps deployments

## Architecture Overview

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                           AWS Cloud                                                 │
│                                                                                                     │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                    EDGE LAYER                                                │   │
│  │                                                                                              │   │
│  │                              ┌─────────────────────────┐                                    │   │
│  │                              │    CloudFront + WAF     │                                    │   │
│  │                              │    (Global Edge CDN)    │                                    │   │
│  │                              └────────────┬────────────┘                                    │   │
│  │                                           │                                                  │   │
│  │              ┌────────────────────────────┼────────────────────────────┐                    │   │
│  │              │                            │                            │                    │   │
│  │              ▼                            ▼                            ▼                    │   │
│  │    ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐             │   │
│  │    │   S3 Bucket     │         │   AWS ALB       │         │  API Gateway    │             │   │
│  │    │ (Static Assets) │         │   (Web LB)      │         │  (HTTP API)     │             │   │
│  │    │                 │         │                 │         │                 │             │   │
│  │    │ /static/*       │         │ /app1, /app2    │         │ /api/*          │             │   │
│  │    │ /*.css, /*.js   │         │ /healthz, /demo │         │                 │             │   │
│  │    └─────────────────┘         └────────┬────────┘         └────────┬────────┘             │   │
│  │                                         │                           │                       │   │
│  └─────────────────────────────────────────┼───────────────────────────┼───────────────────────┘   │
│                                            │                           │                           │
│  ┌─────────────────────────────────────────┼───────────────────────────┼───────────────────────┐   │
│  │                                   VPC   │                           │                        │   │
│  │                                         │                           │                        │   │
│  │   ┌─────────────────────────────────────┼───────────────────────────┼────────────────────┐  │   │
│  │   │                      Private Subnets│                           │                     │  │   │
│  │   │                                     │                           │                     │  │   │
│  │   │                          ┌──────────▼──────────┐     ┌──────────▼──────────┐         │  │   │
│  │   │                          │   Internal NLB      │     │     VPC Link        │         │  │   │
│  │   │                          │ (AWS LB Controller) │     │   (API Gateway)     │         │  │   │
│  │   │                          └──────────┬──────────┘     └──────────┬──────────┘         │  │   │
│  │   │                                     │                           │                     │  │   │
│  │   │                                     └─────────────┬─────────────┘                     │  │   │
│  │   │                                                   │                                   │  │   │
│  │   │                          ┌────────────────────────▼────────────────────────┐         │  │   │
│  │   │                          │              EKS Cluster                        │         │  │   │
│  │   │                          │                                                 │         │  │   │
│  │   │                          │  ┌─────────────────────────────────────────┐   │         │  │   │
│  │   │                          │  │         Istio Gateway (Gateway API)     │   │         │  │   │
│  │   │                          │  └────────────────────┬────────────────────┘   │         │  │   │
│  │   │                          │                       │                         │         │  │   │
│  │   │                          │  ┌────────────────────▼────────────────────┐   │         │  │   │
│  │   │                          │  │              HTTPRoutes                  │   │         │  │   │
│  │   │                          │  │  /app1  /app2  /api/users  /healthz     │   │         │  │   │
│  │   │                          │  └────────────────────┬────────────────────┘   │         │  │   │
│  │   │                          │                       │                         │         │  │   │
│  │   │                          │  ┌────────────────────▼────────────────────┐   │         │  │   │
│  │   │                          │  │           Application Services          │   │         │  │   │
│  │   │                          │  │   app1, app2, users-api, health-resp    │   │         │  │   │
│  │   │                          │  │       (Istio Ambient - no sidecar)      │   │         │  │   │
│  │   │                          │  └─────────────────────────────────────────┘   │         │  │   │
│  │   │                          │                                                 │         │  │   │
│  │   │                          └─────────────────────────────────────────────────┘         │  │   │
│  │   │                                                                                       │  │   │
│  │   └───────────────────────────────────────────────────────────────────────────────────────┘  │   │
│  │                                                                                              │   │
│  └──────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                         TRAFFIC FLOWS                                                 │
├──────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                       │
│  STATIC ASSETS (CSS, JS, Images):                                                                    │
│  ┌──────────┐     ┌─────────────────┐     ┌─────────────────┐                                       │
│  │ Internet │────▶│ CloudFront+WAF  │────▶│    S3 Bucket    │                                       │
│  └──────────┘     │ /static/*       │     │ (Edge Cached)   │                                       │
│                   └─────────────────┘     └─────────────────┘                                       │
│                                                                                                       │
│  WEB TRAFFIC (Dynamic):                                                                              │
│  ┌──────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐              │
│  │ Internet │────▶│ CloudFront+WAF  │────▶│      ALB        │────▶│  Internal NLB   │              │
│  └──────────┘     │ /app1, /app2    │     │ (X-CF-Header)   │     │ (LB Controller) │              │
│                   └─────────────────┘     └─────────────────┘     └────────┬────────┘              │
│                                                                             │                        │
│                                                                             ▼                        │
│                                           ┌─────────────────────────────────────────────┐           │
│                                           │              EKS Cluster                     │           │
│  API TRAFFIC:                             │  ┌─────────────────────────────────────┐    │           │
│  ┌──────────┐     ┌─────────────────┐     │  │         Istio Gateway               │    │           │
│  │ Internet │────▶│ CloudFront+WAF  │     │  │         (Gateway API)               │    │           │
│  └──────────┘     │ /api/*          │     │  └──────────────────┬──────────────────┘    │           │
│                   └────────┬────────┘     │                     │                        │           │
│                            │              │  ┌──────────────────▼──────────────────┐    │           │
│                            ▼              │  │            HTTPRoutes                │    │           │
│                   ┌─────────────────┐     │  │  /app1 /app2 /api/users /healthz    │    │           │
│                   │  API Gateway    │     │  └──────────────────┬──────────────────┘    │           │
│                   │  (HTTP API)     │     │                     │                        │           │
│                   └────────┬────────┘     │  ┌──────────────────▼──────────────────┐    │           │
│                            │              │  │        Application Pods              │    │           │
│                            ▼              │  │   (Istio Ambient - no sidecar)       │    │           │
│                   ┌─────────────────┐     │  └──────────────────────────────────────┘    │           │
│                   │    VPC Link     │─────│                                              │           │
│                   └─────────────────┘     └──────────────────────────────────────────────┘           │
│                                                                                                       │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              DEPLOYMENT LAYERS                                           │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  LAYER 1: Cloud Foundations (Terraform)                                                 │
│  ├── VPC with Public & Private Subnets                                                 │
│  ├── NAT Gateway, Internet Gateway                                                      │
│  └── Route Tables, Security Groups                                                      │
│                                                                                          │
│  LAYER 2: Base EKS Cluster Setup (Terraform)                                            │
│  ├── EKS Cluster with OIDC Provider                                                    │
│  ├── Node Groups (System + User)                                                        │
│  ├── IAM Roles (Cluster, Node, LB Controller, ACK)                                     │
│  ├── ArgoCD Installation                                                                │
│  ├── AWS Load Balancer Controller                                                       │
│  ├── ALB (Application Load Balancer)                                                    │
│  ├── API Gateway HTTP API + VPC Link                                                    │
│  ├── CloudFront Distribution (optional)                                                 │
│  ├── WAF Web ACL (optional)                                                             │
│  └── S3 Bucket for Static Assets (optional)                                             │
│                                                                                          │
│  LAYER 3: EKS Customizations (ArgoCD)                                                   │
│  ├── Istio Ambient Mesh:                                                                │
│  │   ├── istio-base (CRDs)                                                              │
│  │   ├── istiod (Control Plane)                                                         │
│  │   ├── istio-cni (CNI Plugin)                                                         │
│  │   └── ztunnel (L4 mTLS DaemonSet)                                                    │
│  ├── Namespaces (with istio.io/dataplane-mode: ambient)                                │
│  ├── Istio Gateway (creates Internal NLB)                                               │
│  ├── HTTPRoutes (path-based routing)                                                    │
│  └── ACK API Gateway Controller                                                         │
│                                                                                          │
│  LAYER 4: Application Deployment (ArgoCD)                                               │
│  ├── sample-app-1, sample-app-2                                                         │
│  ├── health-responder, demo-app                                                         │
│  ├── users-api                                                                           │
│  └── API Gateway Routes & Integrations (via ACK CRDs)                                   │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## CloudFront Behavior Configuration

| Path Pattern | Origin | Cache Policy | Purpose |
|--------------|--------|--------------|---------|
| `/static/*` | S3 Bucket | CachingOptimized | Static assets (CSS, JS, images) |
| `/*.js`, `/*.css` | S3 Bucket | CachingOptimized | Root-level static files |
| `/api/*` | API Gateway | CachingDisabled | API requests |
| `/app1/*`, `/app2/*` | ALB | CachingDisabled | Dynamic web apps |
| `Default (*)` | ALB | CachingDisabled | All other requests |

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              SECURITY LAYERS                                             │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  EDGE SECURITY (CloudFront + WAF):                                                      │
│  ├── AWS Managed Rules (Core Rule Set)                                                  │
│  ├── Rate Limiting (configurable per IP)                                                │
│  ├── Bot Protection                                                                      │
│  ├── Geo-blocking (optional)                                                            │
│  └── Custom header injection for origin verification                                    │
│                                                                                          │
│  ORIGIN PROTECTION:                                                                      │
│  ├── ALB: Security group allows only CloudFront IPs                                    │
│  ├── ALB: Validates X-CloudFront-Header                                                 │
│  ├── API Gateway: Lambda Authorizer validates secret header                            │
│  └── S3: Origin Access Control (OAC) - CloudFront only                                 │
│                                                                                          │
│  NETWORK SECURITY:                                                                       │
│  ├── Private subnets for EKS nodes                                                      │
│  ├── Internal NLB (not internet-facing)                                                 │
│  ├── Security groups with least privilege                                               │
│  └── Istio Ambient mTLS between pods                                                    │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

| Layer | Tool | What It Creates |
|-------|------|-----------------|
| **Layer 1** | Terraform | VPC, Subnets (Public/Private), NAT/IGW, Route Tables |
| **Layer 2** | Terraform | EKS, IAM, ArgoCD, LB Controller, ALB, API Gateway, CloudFront, WAF, S3 |
| **Layer 3** | ArgoCD | Istio Ambient, Gateway, HTTPRoutes, ACK Controller |
| **Layer 4** | ArgoCD | Applications, API Gateway Routes (via ACK CRDs) |

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl
- Helm 3
- ACM certificate (for ALB/API Gateway HTTPS)
- ACM certificate in us-east-1 (for CloudFront custom domain)

## Deployment Steps

### Step 1: Deploy Infrastructure (Layers 1 & 2)

```bash
cd terraform

# Review and customize variables
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
# Required
region              = "ap-southeast-2"
acm_certificate_arn = "arn:aws:acm:..." # For ALB HTTPS

# API Gateway (optional)
enable_api_gateway = true

# CloudFront + WAF Production Enhancement (optional)
enable_cloudfront           = true   # Enable CloudFront + S3 static assets
enable_waf                  = true   # Enable WAF Web ACL
cloudfront_origin_secret    = "your-secure-secret-value"  # Change this!
upload_sample_static_assets = true   # Upload demo CSS/JS to S3

# For custom CloudFront domain (optional, certificate must be in us-east-1)
# cloudfront_certificate_arn = "arn:aws:acm:us-east-1:..."
# cloudfront_custom_domain   = "www.example.com"
```

Deploy:

```bash
terraform init
terraform apply
```

This creates:
- **Layer 1:** VPC, subnets, NAT gateway
- **Layer 2:** EKS cluster, ArgoCD, AWS LB Controller, ALB, API Gateway foundations
- **Layer 2 (if CloudFront enabled):** CloudFront distribution, WAF, S3 bucket for static assets

### Step 2: Configure kubectl

```bash
# Get credentials
$(terraform output -raw eks_get_credentials_command)
```

### Step 3: Generate TLS Certificates

```bash
./scripts/01-generate-certs.sh
```

### Step 4: Create TLS Secret

```bash
kubectl create namespace istio-ingress
kubectl create secret tls istio-gateway-tls \
  --cert=certs/server.crt \
  --key=certs/server.key \
  -n istio-ingress
```

### Step 5: Deploy ArgoCD Root App (Layers 3 & 4)

```bash
# Get ArgoCD admin password
terraform output -raw argocd_admin_password

# Apply root application
kubectl apply -f argocd/root-app.yaml
```

This deploys via ArgoCD:
- **Layer 3:** Istio Ambient, Gateway, HTTPRoutes, ACK Controller
- **Layer 4:** Sample apps, API routes

### Step 6: Update ACK Configuration (if API Gateway enabled)

```bash
# Get values from Terraform
terraform output ack_apigatewayv2_role_arn
terraform output api_gateway_id
terraform output api_gateway_vpc_link_id

# Update argocd/apps/09-ack-apigatewayv2.yaml with role ARN
# Update k8s/api-gateway/api-gateway-config.yaml with API/VPC Link IDs
```

### Step 7: Register NLB with ALB

```bash
./scripts/06-register-nlb-with-alb.sh
```

> **Why is this step needed?**
>
> The Istio Gateway creates an Internal NLB dynamically via the AWS Load Balancer Controller after Terraform completes. This script:
> 1. Waits for the Gateway to be ready
> 2. Discovers the NLB IP address
> 3. Registers it with the ALB target group

## Project Structure

```
EKS-Istio-GatewayAPI-Demo/
├── terraform/                    # LAYERS 1 & 2
│   ├── main.tf                   # Root module with layer comments
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── modules/
│       ├── vpc/                  # Layer 1: Cloud Foundations
│       ├── eks/                  # Layer 2: EKS Cluster
│       ├── iam/                  # Layer 2: IAM Roles
│       ├── alb/                  # Layer 2: Application Load Balancer
│       ├── argocd/               # Layer 2: ArgoCD Installation
│       ├── lb-controller/        # Layer 2: AWS LB Controller
│       ├── api-gateway/          # Layer 2: API Gateway + VPC Link
│       ├── cloudfront/           # Layer 2: CloudFront + WAF
│       └── static-assets/        # Layer 2: S3 for static files
├── argocd/                       # LAYERS 3 & 4
│   ├── root-app.yaml             # Root application (App of Apps)
│   └── apps/
│       ├── 01-namespaces.yaml        # Layer 3
│       ├── 02-istio-base.yaml        # Layer 3
│       ├── 03-istiod.yaml            # Layer 3
│       ├── 04-istio-cni.yaml         # Layer 3
│       ├── 05-ztunnel.yaml           # Layer 3
│       ├── 06-gateway.yaml           # Layer 3
│       ├── 07-httproutes.yaml        # Layer 3
│       ├── 08-apps.yaml              # Layer 4
│       ├── 09-ack-apigatewayv2.yaml  # Layer 3 (ACK controller)
│       └── 10-api-gateway-config.yaml # Layer 4 (API routes)
├── k8s/
│   ├── namespace.yaml            # Ambient-enabled namespaces
│   ├── apps/                     # Layer 4: Sample applications
│   ├── istio/                    # Layer 3: Gateway & HTTPRoutes
│   └── api-gateway/              # Layer 4: App-specific API routes
├── certs/
└── scripts/
    ├── 01-generate-certs.sh
    └── 06-register-nlb-with-alb.sh
```

## Key Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `region` | ap-southeast-2 | AWS region |
| `kubernetes_version` | 1.31 | EKS Kubernetes version |
| `eks_node_count` | 2 | Number of worker nodes |
| `enable_api_gateway` | false | Enable API Gateway + VPC Link |
| `enable_cloudfront` | false | Enable CloudFront + WAF + S3 |
| `enable_waf` | true | Enable WAF on CloudFront |
| `cloudfront_origin_secret` | (change me) | Secret for origin verification |
| `upload_sample_static_assets` | true | Upload demo CSS/JS to S3 |

## Key Terraform Outputs

| Output | Description |
|--------|-------------|
| `eks_cluster_name` | EKS cluster name |
| `alb_dns_name` | ALB DNS name |
| `argocd_admin_password` | ArgoCD admin password |
| `api_gateway_endpoint` | API Gateway endpoint URL |
| `cloudfront_domain_name` | CloudFront distribution domain |
| `cloudfront_url` | CloudFront URL for web access |
| `static_assets_url` | URL for static assets via CloudFront |
| `static_assets_bucket` | S3 bucket name for static assets |

## Verification

### Test via CloudFront (When Enabled)

```bash
# Get CloudFront domain
CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)

# Test web endpoints via CloudFront
curl -k https://${CF_DOMAIN}/healthz/ready
curl -k https://${CF_DOMAIN}/app1
curl -k https://${CF_DOMAIN}/app2

# Test static assets (served from S3)
curl -I https://${CF_DOMAIN}/static/css/styles.css
curl -I https://${CF_DOMAIN}/static/js/app.js

# Test demo web app
curl https://${CF_DOMAIN}/demo
```

### Test Web Endpoints (via ALB - Direct)

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)

curl -k https://${ALB_DNS}/healthz/ready
curl -k https://${ALB_DNS}/app1
curl -k https://${ALB_DNS}/app2
```

### Test API Endpoints (via API Gateway)

```bash
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)

curl ${API_ENDPOINT}/api/v1/users
curl ${API_ENDPOINT}/api/v2/users
```

### Check ArgoCD Apps

```bash
kubectl get applications -n argocd
```

## Cleanup

```bash
# Delete ArgoCD apps first
kubectl delete -f argocd/root-app.yaml

# Wait for resources to be cleaned up
sleep 60

# Destroy infrastructure
cd terraform
terraform destroy
```

---

## Cost Comparison

| Component | Basic Setup | With CloudFront+WAF | Notes |
|-----------|-------------|---------------------|-------|
| ALB | ~$20/month | ~$20/month | Same |
| CloudFront | $0 | ~$50-100/month | Varies by traffic |
| WAF | $0 | ~$5-10/month | Per Web ACL |
| API Gateway | ~$10/month | ~$10/month | HTTP API pricing |
| S3 (static) | $0 | ~$5/month | Static assets |
| **Total** | ~$30/month | ~$90-145/month | Production security |

---

## Appendix: Cloud Provider Comparison

| Component | Azure (AKS) | AWS (EKS) |
|-----------|-------------|-----------|
| External L7 LB | Azure App Gateway | AWS ALB |
| Internal L4 LB | Azure Internal LB | AWS Internal NLB |
| CDN + WAF | Azure Front Door + WAF | CloudFront + WAF |
| Static Assets | Azure Blob Storage | S3 |
| API Management | Azure APIM | AWS API Gateway |
| API Controller | ASO (Azure Service Operator) | ACK (AWS Controllers for K8s) |
| Service Mesh | Istio Gateway | Istio Gateway |
| Gateway API | Same (Kubernetes standard) | Same (Kubernetes standard) |
| GitOps | ArgoCD | ArgoCD |

## License

MIT License
