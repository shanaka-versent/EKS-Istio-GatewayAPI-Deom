# MTKC POC EKS - ArgoCD Module
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# Layer 2: Base EKS Cluster Setup - ArgoCD Installation
# ArgoCD is installed via Terraform as part of the base cluster setup

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version

  values = [
    yamlencode({
      server = {
        service = {
          type = var.service_type
        }
        extraArgs = var.insecure_mode ? ["--insecure"] : []
      }
      configs = {
        params = {
          "server.insecure" = var.insecure_mode
        }
      }
    })
  ]

  wait    = true
  timeout = 600

  depends_on = [var.cluster_dependency]
}

# Get ArgoCD admin password
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }

  depends_on = [helm_release.argocd]
}
