# 1. Ensure the cluster is healthy before attempting an OS upgrade
data "talos_cluster_health" "health" {
  client_configuration = var.client_configuration
  control_plane_nodes  = [for k, v in var.controlplane_nodes : v.ip]
  worker_nodes         = [for k, v in var.worker_nodes : v.ip]
  endpoints            = [local.target_endpoint]
}

# 2. Execute a rolling OS upgrade (Control Planes first, then Workers)
resource "null_resource" "upgrade_nodes" {
  depends_on = [data.talos_cluster_health.health]

  triggers = {
    talos_version = var.talos_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "==> Starting Talos OS Rolling Upgrade to ${var.talos_version}..."

      # Upgrade Control Planes
      %{for k, v in var.controlplane_nodes~}
      echo " -> Upgrading Control Plane: ${k} (${v.ip}) to ${var.node_images[k]}"
      talosctl --talosconfig ${path.root}/../secrets/talosconfig upgrade \
        --nodes ${v.ip} \
        --endpoints ${local.target_endpoint} \
        --image ${var.node_images[k]} \
        --preserve=true \
        --wait --timeout 15m
      %{endfor~}

      # Upgrade Workers
      %{for k, v in var.worker_nodes~}
      echo " -> Upgrading Worker: ${k} (${v.ip}) to ${var.node_images[k]}"
      talosctl --talosconfig ${path.root}/../secrets/talosconfig upgrade \
        --nodes ${v.ip} \
        --endpoints ${local.target_endpoint} \
        --image ${var.node_images[k]} \
        --preserve=true \
        --wait --timeout 15m
      %{endfor~}

      echo "==> Talos OS Upgrade Complete!"
    EOT
  }
}
