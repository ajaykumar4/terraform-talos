# 1. Ensure cluster is healthy before upgrading Kubernetes
data "talos_cluster_health" "health" {
  client_configuration = var.client_configuration
  control_plane_nodes  = [for k, v in var.controlplane_nodes : v.ip]
  worker_nodes         = [for k, v in var.worker_nodes : v.ip]
  endpoints            = [local.target_endpoint]
}

# 2. Trigger the K8s upgrade via the Control Plane
resource "null_resource" "upgrade_k8s" {
  depends_on = [data.talos_cluster_health.health]

  triggers = {
    kubernetes_version = var.kubernetes_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "==> Upgrading Kubernetes cluster to ${var.kubernetes_version}..."
      talosctl --talosconfig ${path.root}/../secrets/talosconfig upgrade-k8s \
        --nodes ${local.target_endpoint} \
        --endpoints ${local.target_endpoint} \
        --to ${var.kubernetes_version}
    EOT
  }
}
