# MTKC POC EKS - ArgoCD Module
# @author Shanaka Jayasundera - shanakaj@gmail.com
#
# Layer 2: Base EKS Cluster Setup - ArgoCD Installation
# ArgoCD is installed via Terraform as part of the base cluster setup

# Wait for LB controller webhook to be ready
# This prevents "no endpoints available for service aws-load-balancer-webhook-service" errors
# The LB controller installs a mutating webhook that intercepts Service objects
resource "time_sleep" "wait_for_lb_controller" {
  count = var.lb_controller_dependency != null ? 1 : 0

  depends_on = [var.lb_controller_dependency]

  create_duration = "60s"
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version

  values = [
    yamlencode({
      # Global tolerations for all ArgoCD components to run on system nodes
      global = {
        tolerations = [
          {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
            effect   = "NoSchedule"
          }
        ]
        nodeSelector = {
          role = "system"
        }
      }
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

  depends_on = [
    var.cluster_dependency,
    time_sleep.wait_for_lb_controller
  ]
}

# Get ArgoCD admin password
data "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }

  depends_on = [helm_release.argocd]
}
