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
    access_modes = ["ReadWriteMany"]
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

resource "kubernetes_persistent_volume_claim" "wordpress_pvc" {
  metadata {
    name = "wordpress-php-fpm"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.wordpress_pv.metadata[0].name
    storage_class_name = "gp3"
  }
}

## WP PHP-FPM
resource "kubernetes_service" "wordpress-php-fpm" {
  metadata {
    name = "wordpress-php-fpm"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    port {
      port        = 9000
      target_port = 9000
    }
    selector = {
      app  = "wordpress"
      tier = "php-fpm"
    }
    cluster_ip = "None"
  }
}

resource "kubernetes_deployment" "wordpress-php-fpm" {
  metadata {
    name = "wordpress-php-fpm"
    labels = {
      app = "wordpress"
      tier = "php-fpm"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app  = "wordpress"
        tier = "php-fpm"
      }
    }
    template {
      metadata {
        labels = {
          app  = "wordpress"
          tier = "php-fpm"
        }
      }

      spec {
        container {
          image = "wordpress:${var.wordpress_version}"
          name  = "php-fpm"

          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "wp-password"
              }
            }
          }
          env {
            name = "WORDPRESS_DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "wp-user"
              }
            }
          }
          env {
            name = "WORDPRESS_DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "wp-db-name"
              }
            }
          }

          port {
            container_port = 9000
            name           = "php-fpm"
          }

          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
        }

        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql.metadata[0].name
          }
        }
      }
    }
  }
}

## WP NGINX
resource "kubernetes_config_map" "wp-vhost-config" {
  metadata {
    name = "wordpress-nginx-vhost-config"
  }

  data = {
    "wp-vhost.conf" = "${file("${path.module}/wp-vhost.conf")}"
  }
}

resource "kubernetes_service" "wordpress-nginx" {
  metadata {
    name = "wordpress-nginx"
    labels = {
      app = "wordpress"
    }
  }
  spec {
    port {
      port        = 8080
      target_port = 8080
    }
    selector = {
      app  = "wordpress"
      tier = "nginx"
    }
    cluster_ip = "None"
  }
}

resource "kubernetes_deployment" "wordpress-nginx" {
  metadata {
    name = "wordpress-nginx"
    labels = {
      app = "wordpress"
      tier = "nginx"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app  = "wordpress"
        tier = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app  = "wordpress"
          tier = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:${var.nginx_version}"
          name  = "nginx"

          port {
            container_port = 8080
            name           = "http"
          }

          volume_mount {
            name       = "wordpress-persistent-storage"
            mount_path = "/var/www/html"
          }
          volume_mount {
            name       = "wordpress-nginx-vhost-config"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "wp-vhost.conf"
          }
        }

        volume {
          name = "wordpress-persistent-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql.metadata[0].name
          }
        }
        volume {
          name = "wordpress-nginx-vhost-config"
          config_map {
            name = "wordpress-nginx-vhost-config"
          }
        }
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

resource "random_password" "mysql-root-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "mysql-wp-password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "kubernetes_secret" "mysql" {
  metadata {
    name = "mysql-pass"
  }

  data = {
    root-password = random_password.mysql-root-password.result
    wp-password   = random_password.mysql-wp-password.result
    wp-user       = "wp"
    wp-db-name    = "wp"
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
                key  = "root-password"
              }
            }
          }
          env {
            name = "MYSQL_DATABASE"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "wp-db-name"
              }
            }
          }
          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "wp-user"
              }
            }
          }
          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql.metadata[0].name
                key  = "wp-password"
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
