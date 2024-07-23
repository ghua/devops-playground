output "load_balancer_hostname" {
  value = kubernetes_ingress_v1.argocd.status.0.load_balancer.0.ingress.0.hostname
}

output "argocd_admin_password" {
  value     = data.kubernetes_secret_v1.argocd-init.data.password
  sensitive = true
}
