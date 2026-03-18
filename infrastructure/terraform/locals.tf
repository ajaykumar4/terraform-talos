# locals.tf

locals {
  # ----------------------------------------------------------------------------
  # Dynamic Defaults
  # ----------------------------------------------------------------------------

  node_default_gateway          = var.node_default_gateway != "" ? var.node_default_gateway : cidrhost(var.node_cidr, 1)
  bootstrap_kubernetes_api_addr = var.kubernetes_api_addr != "" ? var.kubernetes_api_addr : var.controlplane_nodes[sort(keys(var.controlplane_nodes))[0]].ip

  cilium_bgp_enabled = (
    var.cilium_bgp_router_addr != "" &&
    var.cilium_bgp_router_asn != "" &&
    var.cilium_bgp_node_asn != ""
  )


  # ----------------------------------------------------------------------------
  # File Processing
  # ----------------------------------------------------------------------------

  age_key_content = fileexists(var.age_key_file) ? file(var.age_key_file) : ""
  age_public_key  = length(local.age_key_content) > 0 ? regex("# public key: (age1[\\w]+)", local.age_key_content)[0] : ""
  age_private_key = length(local.age_key_content) > 0 ? regex("(AGE-SECRET-KEY-[\\w]+)", local.age_key_content)[0] : ""

  github_deploy_key = fileexists(var.github_deploy_key_file) ? trimspace(file(var.github_deploy_key_file)) : ""

  cf_tunnel_content = fileexists(var.cloudflare_tunnel_file) ? jsondecode(file(var.cloudflare_tunnel_file)) : null

  cloudflare_tunnel_id = local.cf_tunnel_content != null ? local.cf_tunnel_content["TunnelID"] : ""

  cloudflare_tunnel_token = local.cf_tunnel_content != null ? base64encode(jsonencode({
    a = local.cf_tunnel_content["AccountTag"]
    t = local.cf_tunnel_content["TunnelID"]
    s = local.cf_tunnel_content["TunnelSecret"]
  })) : ""

  kubeconfig_file_path = abspath(var.kubeconfig_path)
  kubeconfig_content   = fileexists(local.kubeconfig_file_path) ? yamldecode(file(local.kubeconfig_file_path)) : null
  kubeconfig_cluster   = local.kubeconfig_content != null ? local.kubeconfig_content.clusters[0].cluster : null
  kubeconfig_user      = local.kubeconfig_content != null ? local.kubeconfig_content.users[0].user : null

  gitops_local_path = abspath(var.gitops_local_path)
}
