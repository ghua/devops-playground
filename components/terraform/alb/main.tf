module "label" {
  source  = "cloudposse/label/null"
  version = "0.25.0"

  attributes = ["cluster"]

  context = module.this.context
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

module "alb" {
  source = "cloudposse/alb/aws"

  vpc_id = data.terraform_remote_state.eks.outputs.eks_vpc_id
  subnet_ids = data.terraform_remote_state.eks.outputs.public_subnet_ids
  security_group_ids = [data.terraform_remote_state.eks.outputs.eks_vpc_default_security_group_id]

  http_enabled = true
  http2_enabled = false
  access_logs_enabled = false
  target_group_target_type = "ip"
  health_check_matcher                = "200-399"

  tags = var.tags

  context = module.this.context
}

module "alb_ingress" {
  source = "cloudposse/alb-ingress/aws"

  namespace                           = var.namespace
  vpc_id                              = data.terraform_remote_state.eks.outputs.eks_vpc_id
  target_group_arn                    = module.alb.default_target_group_arn
  unauthenticated_listener_arns       = [module.alb.http_listener_arn]
  default_target_group_enabled        = false
  unauthenticated_paths               = ["/"]
  unauthenticated_priority            = 100
  health_check_matcher                = "200-399"

  tags = var.tags

  context = module.this.context
}

module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = data.terraform_remote_state.eks.outputs.eks_cluster_identity_oidc_issuer_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
#   version    = "1.4.4"

  set {
    name  = "replicaCount"
    value = 1
  }

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.eks_cluster_id
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
  }
}
