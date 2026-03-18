locals {
  # Flag each node with its role before merging so one loop can render both kinds.
  cp_nodes = { for k, v in var.controlplane_nodes : k => merge(v, { is_cp = true }) }
  wk_nodes = { for k, v in var.worker_nodes : k => merge(v, { is_cp = false }) }

  all_nodes = merge(local.cp_nodes, local.wk_nodes)

  # Use a sorted hostname list so bootstrap target selection is deterministic.
  first_controlplane_ip = var.controlplane_nodes[sort(keys(var.controlplane_nodes))[0]].ip
  kubeconfig_content    = yamldecode(talos_cluster_kubeconfig.this.kubeconfig_raw)
  bootstrap_kubeconfig = yamlencode(merge(local.kubeconfig_content, {
    clusters = [
      for cluster in local.kubeconfig_content.clusters :
      merge(cluster, {
        cluster = merge(cluster.cluster, {
          server = "https://${var.kubernetes_api_addr}:6443"
        })
      })
    ]
  }))

  node_prefix_length = split("/", var.node_cidr)[1]
}
