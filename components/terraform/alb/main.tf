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

module "aws_load_balancer_controller_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = data.terraform_remote_state.eks.outputs.eks_cluster_identity_oidc_issuer_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# bug fix for:
#   Failed deploy model due to AccessDenied: User: arn:aws:sts::768954994656:assumed-role/aws-load-balancer-controller/1721300630144284810
#   is not authorized to perform: elasticloadbalancing:AddTags on resource: arn:aws:elasticloadbalancing:*:*:targetgroup/*/*
#   because no identity-based policy allows the elasticloadbalancing:AddTags action
resource "aws_iam_policy" "add_tags_to_elb_policy" {
  name = "AddTagsToElbPolicyWithNoConditions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:AddTags"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
          "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "add_tags_to_elb_policy" {
  policy_arn = aws_iam_policy.add_tags_to_elb_policy.arn
  role       = module.aws_load_balancer_controller_irsa_role.iam_role_name
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
