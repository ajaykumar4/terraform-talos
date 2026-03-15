##############################################################################
# versions.tf
# Terraform version constraints, required providers, and MinIO S3 backend.
##############################################################################

terraform {
  required_version = ">= 1.6.0"

  ###########################################################################


  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.10.1"
    }

    passbolt = {
      source  = "Bald1nh0/passbolt"
      version = ">= 0.3.0"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.5.0"
    }
  }
}

###############################################################################
# Talos provider — no static config needed; all settings are per-resource
###############################################################################
provider "talos" {}

###############################################################################
# Passbolt provider
# Credentials via environment variables (preferred):
#   TF_VAR_passbolt_private_key  — ASCII-armoured GPG private key contents
#   TF_VAR_passbolt_passphrase   — GPG key passphrase
###############################################################################
provider "passbolt" {
  base_url    = var.passbolt_url
  private_key = var.passbolt_private_key
  passphrase  = var.passbolt_passphrase
}
