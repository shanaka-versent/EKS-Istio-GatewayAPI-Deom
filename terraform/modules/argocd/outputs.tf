# MTKC POC EKS - ArgoCD Module Outputs
# @author Shanaka Jayasundera - shanakaj@gmail.com

output "namespace" {
  description = "ArgoCD namespace"
  value       = helm_release.argocd.namespace
}

output "admin_password" {
  description = "ArgoCD admin password"
  value       = data.kubernetes_secret.argocd_admin.data.password
  sensitive   = true
}

output "release_name" {
  description = "ArgoCD Helm release name"
  value       = helm_release.argocd.name
}
