data "aws_eks_cluster" "my-staging-ue2" {
  name = data.terraform_remote_state.eks.outputs.eks_cluster_id
}

data "terraform_remote_state" "eks" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    region               = var.remote_state_bucket_region
    bucket               = var.remote_state_bucket_id
    key                  = var.remote_state_bucket_key
    workspace_key_prefix = "eks"
  }
}

resource "tls_private_key" "argocd" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "argocd" {
  private_key_pem = tls_private_key.argocd.private_key_pem

  subject {
    common_name  = "argocd.example.com"
    organization = "ARGOCD"
  }

  validity_period_hours = 12

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "argocd" {
  private_key      = tls_private_key.argocd.private_key_pem
  certificate_body = tls_self_signed_cert.argocd.cert_pem
}

resource "kubernetes_ingress_v1" "argocd" {
  wait_for_load_balancer = true
  metadata {
    name = "argocd"
    annotations = {
      "kubernetes.io/ingress.class"           = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.argocd.arn
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
    }
  }

  spec {
    default_backend {
      service {
        name = "argocd-server"
        port {
          number = 80
        }
      }
    }

    rule {
      http {
        path {
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }

          path = "/*"
        }
      }
    }
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace = "default"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"

  set {
    name  = "global.domain"
    value = tls_self_signed_cert.argocd.subject[0].common_name
  }
  set {
    name = "configs.params.server\\.insecure"
    value = true
  }
}
