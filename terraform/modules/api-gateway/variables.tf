# MTKC POC EKS - AWS API Gateway Foundations Module Variables
# @author Shanaka Jayasundera - shanakaj@gmail.com

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for VPC Link"
  type        = list(string)
}

# Custom Domain Configuration
variable "custom_domain" {
  description = "Custom domain name for API Gateway (optional)"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain (required if custom_domain is set)"
  type        = string
  default     = ""
}

# CORS Configuration
variable "cors_allow_origins" {
  description = "Allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allow_methods" {
  description = "Allowed HTTP methods for CORS"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD", "PATCH"]
}

variable "cors_allow_headers" {
  description = "Allowed headers for CORS"
  type        = list(string)
  default     = ["Content-Type", "Authorization", "X-Amz-Date", "X-Api-Key", "X-Amz-Security-Token"]
}

variable "cors_expose_headers" {
  description = "Exposed headers for CORS"
  type        = list(string)
  default     = []
}

variable "cors_max_age" {
  description = "Max age for CORS preflight cache (seconds)"
  type        = number
  default     = 300
}

variable "cors_allow_credentials" {
  description = "Allow credentials for CORS"
  type        = bool
  default     = false
}

# Logging Configuration
variable "enable_access_logs" {
  description = "Enable CloudWatch access logs for API Gateway"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Tags
variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
