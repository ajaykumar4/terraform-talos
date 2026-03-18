terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}
