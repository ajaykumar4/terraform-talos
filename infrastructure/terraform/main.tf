# ==============================================================================
# 1. Global Module (Always Runs)
# Generates the foundational cryptographic secrets for the cluster
# ==============================================================================
module "global" {
  source = "./modules/global"

  # Basic Cluster Info
  cluster_name  = var.cluster_name
  talos_version = var.talos_version

  # Networking API & TLS
  cluster_api_addr     = var.cluster_api_addr
  cluster_api_tls_sans = var.cluster_api_tls_sans

  # CIDR Blocks
  node_cidr        = var.node_cidr
  cluster_pod_cidr = var.cluster_pod_cidr
  cluster_svc_cidr = var.cluster_svc_cidr

  # External Services
  node_ntp_servers = var.node_ntp_servers
  node_dns_servers = var.node_dns_servers

  # Node Maps (Required for node_images calculation)
  controlplane_nodes = var.controlplane_nodes
  worker_nodes       = var.worker_nodes
}

# ==============================================================================
# 2. Bootstrap Talos
# Creates the cluster, generates configurations, and fetches the kubeconfig
# ==============================================================================
module "bootstrap_talos" {
  source = "./modules/bootstrap/talos"
  count  = var.run_bootstrap_talos ? 1 : 0

  # 1. Pass computed values from Global Module
  node_images            = module.global.node_images
  common_machine_patches = module.global.common_machine_patches
  controller_patches     = module.global.controller_patches

  # 2. Required Infrastructure Variables
  cluster_name         = var.cluster_name
  cluster_api_addr     = var.cluster_api_addr
  talos_version        = var.talos_version
  kubernetes_version   = var.kubernetes_version
  bootstrap_generation = var.bootstrap_generation
  kubernetes_api_addr  = local.bootstrap_kubernetes_api_addr
  node_cidr            = var.node_cidr
  node_default_gateway = local.node_default_gateway
  node_vlan_tag        = var.node_vlan_tag

  # 3. Node Maps
  controlplane_nodes = var.controlplane_nodes
  worker_nodes       = var.worker_nodes

  # Secrets from the global module
  client_configuration = module.global.client_configuration
  machine_secrets      = module.global.machine_secrets
}

# ==============================================================================
# 3. Render GitOps Assets
# Keeps the repository-local GitOps files aligned with Terraform variables.
# ==============================================================================
module "gitops_assets" {
  source = "./modules/gitops-assets"

  gitops_local_path        = local.gitops_local_path
  cloudflare_domain        = var.cloudflare_domain
  cloudflare_token         = var.cloudflare_token
  cloudflare_tunnel_id     = local.cloudflare_tunnel_id
  cloudflare_tunnel_token  = local.cloudflare_tunnel_token
  cluster_dns_gateway_addr = var.cluster_dns_gateway_addr
  cluster_gateway_addr     = var.cluster_gateway_addr
  cloudflare_gateway_addr  = var.cloudflare_gateway_addr
  node_cidr                = var.node_cidr
  cluster_pod_cidr         = var.cluster_pod_cidr
  cilium_bgp_enabled       = local.cilium_bgp_enabled
  cilium_bgp_router_addr   = var.cilium_bgp_router_addr
  cilium_bgp_router_asn    = var.cilium_bgp_router_asn
  cilium_bgp_node_asn      = var.cilium_bgp_node_asn
  age_public_key           = local.age_public_key
}

# ==============================================================================
# 4. Bootstrap Apps (GitOps, Cilium, Cloudflare, etc.)
# Deploys core helm charts and bootstraps Argo CD applications after the cluster is up
# ==============================================================================
module "bootstrap_apps" {
  source = "./modules/bootstrap/apps"
  count  = var.run_bootstrap_apps ? 1 : 0

  depends_on = [module.gitops_assets, module.bootstrap_talos]

  # GitOps / GitHub
  repository_name       = var.repository_name
  repository_branch     = var.repository_branch
  repository_visibility = var.repository_visibility
  github_deploy_key     = local.github_deploy_key

  # Age / SOPS Secrets
  age_private_key     = local.age_private_key
  kubeconfig_path     = abspath(var.kubeconfig_path)
  kubeconfig_raw      = try(module.bootstrap_talos[0].kubeconfig_raw, null)
  kubernetes_api_addr = local.bootstrap_kubernetes_api_addr
  gitops_dir          = local.gitops_local_path
  gitops_repo_path    = var.gitops_repo_path

  # Networking
  cilium_bgp_enabled       = local.cilium_bgp_enabled
  cluster_pod_cidr         = var.cluster_pod_cidr
  cilium_loadbalancer_mode = var.cilium_loadbalancer_mode
}

# ==============================================================================
# 5. Day 2 Operations: Upgrade Kubernetes
# ==============================================================================
module "talos_upgrade_k8s" {
  source = "./modules/talos/upgrade-k8s"
  count  = var.run_upgrade_k8s ? 1 : 0

  client_configuration = module.global.client_configuration
  kubernetes_version   = var.kubernetes_version
  controlplane_nodes   = var.controlplane_nodes
  worker_nodes         = var.worker_nodes
}

# ==============================================================================
# 6. Day 2 Operations: Upgrade Talos Nodes
# ==============================================================================
module "talos_upgrade_nodes" {
  source = "./modules/talos/upgrade-nodes"
  count  = var.run_upgrade_nodes ? 1 : 0

  client_configuration = module.global.client_configuration
  talos_version        = var.talos_version
  controlplane_nodes   = var.controlplane_nodes
  worker_nodes         = var.worker_nodes
  node_images          = module.global.node_images
}

# ==============================================================================
# 7. Day 2 Operations: Reset Cluster
# ==============================================================================
module "talos_reset" {
  source = "./modules/talos/reset"
  count  = var.run_reset ? 1 : 0

  client_configuration = module.global.client_configuration
  controlplane_nodes   = var.controlplane_nodes
  worker_nodes         = var.worker_nodes
}
