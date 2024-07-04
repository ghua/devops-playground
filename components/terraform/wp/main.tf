data "aws_eks_cluster" "my-staging-ue2" {
  name = data.terraform_remote_state.eks.outputs.eks_cluster_id
}

locals {
  eks_cluster_id              = data.terraform_remote_state.eks.outputs.eks_cluster_id
  eks_cluster_arn             = data.terraform_remote_state.eks.outputs.eks_cluster_arn
  eks_cluster_oidc_issuer_url = data.aws_eks_cluster.my-staging-ue2.identity[0].oidc[0].issuer
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

# K8S
## Wordpress Mysql EFS PV
resource "aws_efs_file_system" "wordpress_mysql_efs" {
}

resource "aws_efs_access_point" "wordpress_mysql_efs_ap" {
  file_system_id = aws_efs_file_system.wordpress_mysql_efs.id
}

resource "aws_efs_mount_target" "wordpress_mysql_efs_target" {
  count = length(data.terraform_remote_state.eks.outputs.private_subnet_ids)
  file_system_id = aws_efs_file_system.wordpress_mysql_efs.id
  subnet_id      = data.terraform_remote_state.eks.outputs.private_subnet_ids[count.index]
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
    storage_class_name = "gp3"
    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.wordpress_mysql_efs.id
      }
    }
  }
}

## Wordpress EFS PV
resource "aws_efs_file_system" "wordpress_efs" {
}

resource "aws_efs_access_point" "wordpress_efs_ap" {
  file_system_id = aws_efs_file_system.wordpress_efs.id
}

resource "aws_efs_mount_target" "wordpress_efs_target" {
  count = length(data.terraform_remote_state.eks.outputs.private_subnet_ids)
  file_system_id = aws_efs_file_system.wordpress_efs.id
  subnet_id      = data.terraform_remote_state.eks.outputs.private_subnet_ids[count.index]
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
    storage_class_name = "gp3"
    persistent_volume_source {
      csi {
        driver = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.wordpress_efs.id
      }
    }
  }
}

### MySQL
resource "kubernetes_service" "mysql" {
  metadata {
    name = "wordpress-mysql"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    port {
      port        = 3306
      target_port = 3306
    }
    selector = {
      app  = "wordpress"
      tier = "mysql"
    }
    cluster_ip = "None"
  }
}

resource "kubernetes_persistent_volume_claim" "mysql" {
  metadata {
    name = "mysql-pv-claim"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.wordpress_mysql_pv.metadata[0].name
    storage_class_name = "gp3"
  }
}

resource "kubernetes_secret" "mysql" {
  metadata {
    name = "mysql-pass"
  }

  data = {
    password = var.mysql_password
  }
}

resource "kubernetes_deployment" "mysql" {
  metadata {
    name = "wordpress-mysql"
    labels = {
      app = "wordpress"
      tier = "mysql"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app  = "wordpress"
        tier = "mysql"
      }
    }
    template {
      metadata {
        labels = {
          app  = "wordpress"
          tier = "mysql"
        }
      }

      spec {
        container {
          image = "mysql:${var.mysql_version}"
          name  = "mysql"

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "password"
              }
            }
          }

          port {
            container_port = 3306
            name           = "mysql"
          }

          volume_mount {
            name       = "mysql-persistent-storage"
            mount_path = "/var/lib/mysql"
          }
        }

        volume {
          name = "mysql-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql.metadata[0].name
          }
        }
      }
    }
  }
}
