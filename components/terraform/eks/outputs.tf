output "public_subnet_cidrs" {
  value       = module.subnets.public_subnet_cidrs
  description = "Public subnet CIDRs"
}

output "private_subnet_cidrs" {
  value       = module.subnets.private_subnet_cidrs
  description = "Private subnet CIDRs"
}

output "vpc_cidr" {
  value       = module.vpc.vpc_cidr_block
  description = "VPC ID"
}

output "private_subnet_ids" {
  value       = module.subnets.private_subnet_ids
  description = "Private subnets"
}

output "eks_cluster_id" {
  description = "The name of the cluster"
  value       = module.eks_cluster.eks_cluster_id
}

output "eks_cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_cluster.eks_cluster_arn
}

output "eks_cluster_endpoint" {
  description = "The endpoint for the Kubernetes API server"
  value       = module.eks_cluster.eks_cluster_endpoint
}

output "eks_cluster_version" {
  description = "The Kubernetes server version of the cluster"
  value       = module.eks_cluster.eks_cluster_version
}

output "eks_cluster_identity_oidc_issuer" {
  description = "The OIDC Identity issuer for the cluster"
  value       = module.eks_cluster.eks_cluster_identity_oidc_issuer
}

output "eks_cluster_managed_security_group_id" {
  description = "Security Group ID that was created by EKS for the cluster. EKS creates a Security Group and applies it to ENI that is attached to EKS Control Plane master nodes and to any managed workloads"
  value       = module.eks_cluster.eks_cluster_managed_security_group_id
}

output "eks_cluster_ipv6_service_cidr" {
  description = <<-EOT
    The IPv6 CIDR block that Kubernetes pod and service IP addresses are assigned from
    if `kubernetes_network_ipv6_enabled` is set to true. If set to false this output will be null.
    EOT
  value       = module.eks_cluster.eks_cluster_ipv6_service_cidr
}

output "eks_node_group_role_arn" {
  description = "ARN of the worker nodes IAM role"
  value       = module.eks_node_group.eks_node_group_role_arn
}

output "eks_node_group_role_name" {
  description = "Name of the worker nodes IAM role"
  value       = module.eks_node_group.eks_node_group_role_name
}

output "eks_node_group_id" {
  description = "EKS Cluster name and EKS Node Group name separated by a colon"
  value       = module.eks_node_group.eks_node_group_id
}

output "eks_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = module.eks_node_group.eks_node_group_arn
}

output "eks_node_group_resources" {
  description = "List of objects containing information about underlying resources of the EKS Node Group"
  value       = module.eks_node_group.eks_node_group_resources
}

output "eks_node_group_status" {
  description = "Status of the EKS Node Group"
  value       = module.eks_node_group.eks_node_group_status
}

output "eks_vpc_default_security_group_id" {
  value       = module.vpc.vpc_default_security_group_id
  description = "EKS VPS default security group id"
}

output "eks_vpc_id" {
  value       = module.vpc.vpc_id
  description = "EKS VPS id"
}

output "public_subnet_ids" {
  value       = module.subnets.public_subnet_ids
  description = "EKS public subnets id"
}

output "eks_cluster_identity_oidc_issuer_arn" {
  value = module.eks_cluster.eks_cluster_identity_oidc_issuer_arn
}