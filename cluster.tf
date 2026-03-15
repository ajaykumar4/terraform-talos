##############################################################################
# cluster.tf
# Bootstrap the cluster, retrieve kubeconfig, and lifecycle operations.
##############################################################################

###############################################################################
# Bootstrap — initialises etcd on the first control-plane node.
# Equivalent to: talosctl bootstrap --nodes 192.168.8.2
###############################################################################
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_controlplane_ip
  endpoint             = local.first_controlplane_ip

  depends_on = [talos_machine_configuration_apply.controlplane]

  timeouts = {
    create = "20m"
  }
}

###############################################################################
# Kubeconfig — fetches the admin kubeconfig after bootstrap.
###############################################################################
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_controlplane_ip
  endpoint             = local.first_controlplane_ip

  depends_on = [talos_machine_bootstrap.this]

  timeouts = {
    create = "10m"
    read   = "10m"
  }
}

###############################################################################
# OPERATION: Upgrade Talos OS
# Set var.upgrade-nodes = true to trigger.
# Upgrades sequentially: control-planes → workers.
###############################################################################
resource "null_resource" "upgrade_talos" {
  count = var.upgrade-nodes ? 1 : 0

  triggers = {
    talos_version = var.talos_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      set -euo pipefail

      TMPDIR=$(mktemp -d)
      TALOSCONFIG="$TMPDIR/talosconfig"
      cat > "$TALOSCONFIG" <<'TALOSEOF'
${data.talos_client_configuration.this.talos_config}
TALOSEOF

      # Control-plane nodes
      for KV in ${join(" ", [for k, v in local.controlplane_nodes : "${v.ip},${v.schematic_id != "" ? "factory.talos.dev/installer/${v.schematic_id}" : "ghcr.io/siderolabs/installer"}:${var.talos_version}"])}; do
        NODE="$${KV%,*}"
        IMAGE="$${KV#*,}"
        echo "==> [UPGRADE TALOS] Control-plane $NODE → $IMAGE"
        TALOSCONFIG="$TALOSCONFIG" talosctl upgrade \
          --nodes "$NODE" \
          --endpoints "${local.first_controlplane_ip}" \
          --image "$IMAGE" \
          --wait --timeout 10m
      done

      # Worker nodes
      for KV in ${join(" ", [for k, v in local.worker_nodes : "${v.ip},${v.schematic_id != "" ? "factory.talos.dev/installer/${v.schematic_id}" : "ghcr.io/siderolabs/installer"}:${var.talos_version}"])}; do
        NODE="$${KV%,*}"
        IMAGE="$${KV#*,}"
        echo "==> [UPGRADE TALOS] Worker $NODE → $IMAGE"
        TALOSCONFIG="$TALOSCONFIG" talosctl upgrade \
          --nodes "$NODE" \
          --endpoints "${local.first_controlplane_ip}" \
          --image "$IMAGE" \
          --wait --timeout 10m
      done

      rm -rf "$TMPDIR"
      echo "==> [UPGRADE TALOS] Complete."
    EOT
  }

  depends_on = [talos_cluster_kubeconfig.this]
}

###############################################################################
# OPERATION: Upgrade Kubernetes
# Set var.upgrade-k8s = true to trigger.
###############################################################################
resource "null_resource" "upgrade_k8s" {
  count = var.upgrade-k8s ? 1 : 0

  triggers = {
    kubernetes_version = var.kubernetes_version
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOT
      set -euo pipefail

      TMPDIR=$(mktemp -d)
      TALOSCONFIG="$TMPDIR/talosconfig"
      cat > "$TALOSCONFIG" <<'TALOSEOF'
${data.talos_client_configuration.this.talos_config}
TALOSEOF

      echo "==> [UPGRADE K8S] Upgrading Kubernetes → ${var.kubernetes_version}"
      TALOSCONFIG="$TALOSCONFIG" talosctl upgrade-k8s \
        --nodes "${local.first_controlplane_ip}" \
        --endpoints "${local.first_controlplane_ip}" \
        --to "${var.kubernetes_version}"

      rm -rf "$TMPDIR"
      echo "==> [UPGRADE K8S] Complete."
    EOT
  }

  depends_on = [
    talos_cluster_kubeconfig.this,
    null_resource.upgrade_talos,
  ]
}

###############################################################################
# OPERATION: Cluster Reset ⚠️ DESTRUCTIVE
# Set var.reset = true to trigger. Wipes ALL nodes.
###############################################################################
resource "null_resource" "reset_nodes" {
  count = var.reset ? 1 : 0

  triggers = {
    # If the user sets reset=true, trigger this exactly once
    action = var.reset
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command = <<-EOT
      set -euo pipefail

      TMPDIR=$(mktemp -d)
      TALOSCONFIG="$TMPDIR/talosconfig"
      cat > "$TALOSCONFIG" <<'TALOSEOF'
${data.talos_client_configuration.this.talos_config}
TALOSEOF

      # Convert all node IPs (both CP and workers) into a space-separated string
      ALL_NODES="${join(" ", concat(
    [for k, v in local.controlplane_nodes : v.ip],
    [for k, v in local.worker_nodes : v.ip]
))}"

      for NODE in $ALL_NODES; do
        echo "==> [RESET] ⚠️  Wiping $NODE — THIS IS DESTRUCTIVE!"
        TALOSCONFIG="$TALOSCONFIG" talosctl reset \
          --nodes "$NODE" \
          --endpoints "${local.first_controlplane_ip}" \
          --graceful \
          --reboot \
          --wait=false
      done

      rm -rf "$TMPDIR"
      echo "==> [RESET] Cluster reset complete."
    EOT
}

depends_on = [talos_cluster_kubeconfig.this]
}
