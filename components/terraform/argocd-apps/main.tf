locals {
  argocd_values = templatefile("./helm-values/argocd-min.yaml",
    {
      domain_name = data.terraform_remote_state.argocd-init.outputs.cert_hostname
    }
  )

  argocd_apps_values = templatefile("./helm-values/argocd-apps.yaml",
    {
      cluster_id = data.aws_eks_cluster.my-staging-ue2.id
    }
  )

  apps = [
    {
      name         = "argocd"
      namespace    = "argo"
      project      = "default"
      chart        = "argo-cd"
      repository   = "https://argoproj.github.io/argo-helm"
      version      = "5.46.7"
      values       = local.argocd_values
      sync_wave    = 12
      sync_options = ["ServerSideApply=true"]
      cluster      = "in-cluster"
    },
    {
      name       = "argocd-apps"
      namespace  = "argo"
      project    = "default"
      chart      = "argocd-apps"
      version    = "0.0.1"
      repository = "https://argoproj.github.io/argo-helm"
      values     = local.argocd_apps_values
      sync_wave  = 11
      cluster    = "in-cluster"
    }
  ]
}

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

data "terraform_remote_state" "argocd-init" {
  backend   = "s3"
  workspace = terraform.workspace

  config = {
    region               = var.remote_state_bucket_region
    bucket               = var.remote_state_bucket_id
    key                  = var.remote_state_bucket_key
    workspace_key_prefix = "argocd-init"
  }
}

module "apps" {
  source  = "rallyware/apps/argocd"
  version = "0.2.3"

  parent_app = {
    name      = "argocd"
    project   = "default"
    namespace = "argo"
    destination = {
      namespace = "argo"
    }
  }

  apps = local.apps

  namespace = "argo"

  context = module.this.context
}
