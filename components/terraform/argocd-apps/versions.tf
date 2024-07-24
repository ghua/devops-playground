terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.7"
    }
    utils = {
      source  = "cloudposse/utils"
      version = ">= 0.14.0"
    }
    argocd = {
      source  = "oboukili/argocd"
      version = ">= 6"
    }
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.17"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
    htpasswd = {
      source  = "loafoe/htpasswd"
      version = ">= 1.0"
    }
  }
}
