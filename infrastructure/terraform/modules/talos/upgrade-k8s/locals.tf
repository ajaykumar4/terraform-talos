locals {
  target_endpoint = var.controlplane_nodes[sort(keys(var.controlplane_nodes))[0]].ip
}
