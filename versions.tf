terraform {
  required_version = ">= 1.3.0"

  required_providers {
    matchbox = {
      source  = "poseidon/matchbox"
      version = "0.5.4"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
  }
}