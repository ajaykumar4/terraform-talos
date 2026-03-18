terraform {
  required_version = ">= 1.6.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13.0"
    }
  }
}

provider "kubernetes" {
  host                   = local.kubeconfig_cluster != null ? "https://${local.bootstrap_kubernetes_api_addr}:6443" : null
  cluster_ca_certificate = local.kubeconfig_cluster != null ? base64decode(local.kubeconfig_cluster["certificate-authority-data"]) : null
  client_certificate     = local.kubeconfig_user != null ? base64decode(local.kubeconfig_user["client-certificate-data"]) : null
  client_key             = local.kubeconfig_user != null ? base64decode(local.kubeconfig_user["client-key-data"]) : null
}

provider "helm" {
  kubernetes {
    host                   = local.kubeconfig_cluster != null ? "https://${local.bootstrap_kubernetes_api_addr}:6443" : null
    cluster_ca_certificate = local.kubeconfig_cluster != null ? base64decode(local.kubeconfig_cluster["certificate-authority-data"]) : null
    client_certificate     = local.kubeconfig_user != null ? base64decode(local.kubeconfig_user["client-certificate-data"]) : null
    client_key             = local.kubeconfig_user != null ? base64decode(local.kubeconfig_user["client-key-data"]) : null
  }
}
