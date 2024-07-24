provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.my-staging-ue2.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.my-staging-ue2.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.my-staging-ue2.name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.my-staging-ue2.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.my-staging-ue2.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.my-staging-ue2.name]
    command     = "aws"
  }
}

provider "argocd" {
  server_addr = data.terraform_remote_state.argocd-init.outputs.load_balancer_hostname
  username    = "admin"
  password    = data.terraform_remote_state.argocd-init.outputs.argocd_admin_password
  grpc_web    = true
  insecure    = true
}

