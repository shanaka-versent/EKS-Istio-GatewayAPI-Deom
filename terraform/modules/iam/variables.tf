# IAM Module Variables
# @author Shanaka Jayasundera - shanakaj@gmail.com

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "create_lb_controller_role" {
  description = "Create IAM role for AWS Load Balancer Controller"
  type        = bool
  default     = false
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN (required for LB controller role)"
  type        = string
  default     = ""
}

variable "oidc_provider_url" {
  description = "EKS OIDC provider URL without https:// (required for LB controller role)"
  type        = string
  default     = ""
}

variable "create_ack_apigatewayv2_role" {
  description = "Create IAM role for ACK API Gateway v2 Controller"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}
