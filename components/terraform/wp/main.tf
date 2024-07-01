provider "aws" {
  region = var.region
}

locals {
  eks_cluster_id  = data.terraform_remote_state.eks.outputs.eks_cluster_id
  eks_cluster_arn = data.terraform_remote_state.eks.outputs.eks_cluster_arn
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

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = local.eks_cluster_arn
}

resource "kubernetes_namespace" "test" {
  metadata {
    name = "test"
  }
}

resource "aws_efs_file_system" "wordpress_mysql_efs" {
  availability_zone_name = var.availability_zones[0]
}

resource "aws_efs_access_point" "wordpress_mysql_efs_ap" {
  file_system_id = aws_efs_file_system.wordpress_mysql_efs.id
}

resource "kubernetes_persistent_volume" "wordpress_mysql_pv" {
  metadata {
    name = "wordpress-mysql"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Delete"
    storage_class_name = ""
    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        volume_handle = aws_efs_access_point.wordpress_mysql_efs_ap.id
      }
    }
  }
}


resource "aws_efs_file_system" "wordpress_efs" {
  availability_zone_name = var.availability_zones[0]
}

resource "aws_efs_access_point" "wordpress_efs_ap" {
  file_system_id = aws_efs_file_system.wordpress_mysql_efs.id
}

resource "kubernetes_persistent_volume" "wordpress_pv" {
  metadata {
    name = "wordpress"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_reclaim_policy = "Delete"
    storage_class_name = ""
    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        volume_handle = aws_efs_access_point.wordpress_efs_ap.id
      }
    }
  }
}
