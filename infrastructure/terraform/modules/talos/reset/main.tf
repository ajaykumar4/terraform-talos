# We check health just to ensure the API is reachable before sending reset commands
data "talos_cluster_health" "health" {
  client_configuration = var.client_configuration
  control_plane_nodes  = [for k, v in var.controlplane_nodes : v.ip]
  worker_nodes         = [for k, v in var.worker_nodes : v.ip]
  endpoints            = [local.target_endpoint]
}

resource "null_resource" "reset_cluster" {
  depends_on = [data.talos_cluster_health.health]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "==> Commencing Cluster Teardown..."

      # 1. Reset Workers First
      %{for k, v in var.worker_nodes~}
      echo " -> Resetting Worker: ${k} (${v.ip})"
      talosctl --talosconfig ${path.root}/../secrets/talosconfig reset \
        --nodes ${v.ip} \
        --endpoints ${local.target_endpoint} \
        --system-labels-to-wipe STATE \
        --system-labels-to-wipe EPHEMERAL \
        --reboot \
        --graceful=false || true
      %{endfor~}

      # 2. Reset Control Planes
      %{for k, v in var.controlplane_nodes~}
      echo " -> Resetting Control Plane: ${k} (${v.ip})"
      talosctl --talosconfig ${path.root}/../secrets/talosconfig reset \
        --nodes ${v.ip} \
        --endpoints ${local.target_endpoint} \
        --system-labels-to-wipe STATE \
        --system-labels-to-wipe EPHEMERAL \
        --reboot \
        --graceful=false || true
      %{endfor~}

      echo "==> Reset commands issued to all nodes."
    EOT
  }
}
