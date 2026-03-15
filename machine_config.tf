##############################################################################
# machine_config.tf
# Generates and applies Talos machine configurations to every node.
##############################################################################

###############################################################################
# talosconfig — client credential
###############################################################################
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration

  # Use all controlplane IPs as endpoints/nodes
  endpoints = [for k, v in local.controlplane_nodes : v.ip]
  nodes     = [for k, v in local.controlplane_nodes : v.ip]
}

###############################################################################
# Control-plane machine configurations
# One per controlplane node — merges global + controller + per-node patches
###############################################################################
data "talos_machine_configuration" "controlplane" {
  for_each = local.controlplane_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Patches applied (order matters):
  #   1. Global patches (from locals.tf → patches_global)
  #   2. Controller patches (from locals.tf → patch_controller_cluster)
  #   3. Per-node network + install patch (from locals.tf → patches_per_node)
  config_patches = concat(
    local.patches_controlplane,
    local.patches_per_node[each.key]
  )
}

###############################################################################
# Worker machine configurations
###############################################################################
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  # Workers get global patches + their per-node network/install patch
  config_patches = concat(
    local.patches_global,
    local.patches_per_node[each.key]
  )
}

###############################################################################
# Apply configuration — control-plane nodes
###############################################################################
resource "talos_machine_configuration_apply" "controlplane" {
  for_each = local.controlplane_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip

  # Extra certSANs to add to the generated config (matches additionalApiServerCertSans)
  # NOTE: with provider >= 0.10 cert SANs are patched in via the config_patches above
  # so this is a belt-and-suspenders addition.

  timeouts = {
    create = "10m"
    update = "10m"
  }
}

###############################################################################
# Apply configuration — worker nodes
###############################################################################
resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip

  timeouts = {
    create = "10m"
    update = "10m"
  }
}
