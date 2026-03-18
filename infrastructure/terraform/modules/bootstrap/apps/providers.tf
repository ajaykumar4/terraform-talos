terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}
