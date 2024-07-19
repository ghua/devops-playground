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

module "apps" {
  source  = "rallyware/apps/argocd"
  version = "0.2.3"

  parent_app = {
    name    = format("%s-bootstrap-main", data.aws_eks_cluster.my-staging-ue2.id)
    project = "test"
  }

  apps = []

  context = module.this.context
}
