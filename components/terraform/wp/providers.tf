provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host = data.aws_eks_cluster.my-staging-ue2.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.my-staging-ue2.certificate_authority[0].data)
}
