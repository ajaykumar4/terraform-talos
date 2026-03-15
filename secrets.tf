##############################################################################
# secrets.tf
# talos_machine_secrets — the cryptographic root of the cluster.
#
# These are equivalent to talsecret.sops.yaml (the SOPS-encrypted file).
# On fresh deploys Terraform generates new secrets and stores them in state.
#
# ⚠️  IMPORTANT: If you are IMPORTING an existing cluster you must supply the
# existing secrets. Use `terraform import talos_machine_secrets.this _` and
# then override the resource with the machine_secrets attribute from your
# talsecret.sops.yaml (after decrypting with `sops -d`).
##############################################################################

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}
