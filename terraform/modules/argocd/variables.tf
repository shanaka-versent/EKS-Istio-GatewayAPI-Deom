# MTKC POC EKS - ArgoCD Module Variables
# @author Shanaka Jayasundera - shanakaj@gmail.com

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "service_type" {
  description = "ArgoCD server service type (LoadBalancer or ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

variable "insecure_mode" {
  description = "Enable insecure mode (no TLS on ArgoCD server)"
  type        = bool
  default     = true
}

variable "cluster_dependency" {
  description = "Dependency to ensure EKS cluster is ready"
  type        = any
  default     = null
}

variable "lb_controller_dependency" {
  description = "Dependency to ensure LB controller webhook is ready before ArgoCD deploys services"
  type        = any
  default     = null
}
