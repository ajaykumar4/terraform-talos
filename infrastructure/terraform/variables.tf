# ==============================================================================
# Talos (Feature Toggles & Operations)
# ==============================================================================

variable "run_bootstrap_talos" {
  type        = bool
  description = "Feature toggle to bootstrap the Talos cluster"
  default     = false
}

variable "bootstrap_generation" {
  type        = number
  description = "Increment this to force the Talos bootstrap resource to run again after a reset or partial rebuild."
  default     = 0
}

variable "run_bootstrap_apps" {
  type        = bool
  description = "Feature toggle to bootstrap the core GitOps applications"
  default     = false
}

variable "run_reset" {
  type        = bool
  description = "Feature toggle to reset the Talos cluster back to maintenance mode"
  default     = false
}

variable "run_upgrade_k8s" {
  type        = bool
  description = "Feature toggle to trigger a Kubernetes version upgrade"
  default     = false
}

variable "run_upgrade_nodes" {
  type        = bool
  description = "Feature toggle to trigger a Talos OS node upgrade"
  default     = false
}

variable "talos_version" {
  type        = string
  description = "The version of Talos OS to install or upgrade to"
  default     = "v1.12.5"
}

variable "kubernetes_version" {
  type        = string
  description = "The version of Kubernetes to install or upgrade to"
  default     = "v1.32.2"
}

# ==============================================================================
# Network
# ==============================================================================

variable "node_cidr" {
  type        = string
  description = "The network CIDR for the nodes (e.g. 192.168.1.0/24)"

  validation {
    condition     = can(cidrhost(var.node_cidr, 0))
    error_message = "node_cidr must be a valid IPv4 CIDR such as \"192.168.1.0/24\"."
  }
}

variable "node_default_gateway" {
  type        = string
  description = "The default gateway for the nodes. If left empty, Terraform will compute the first IP of node_cidr."
  default     = ""
}

variable "node_dns_servers" {
  type        = list(string)
  description = "DNS servers to use for the cluster"
  default     = ["1.1.1.1", "1.0.0.1"]
}

variable "node_ntp_servers" {
  type        = list(string)
  description = "NTP servers to use for the cluster"
  default     = ["162.159.200.1", "162.159.200.123"]
}

variable "node_vlan_tag" {
  type        = string
  description = "Attach a vlan tag to the Talos nodes"
  default     = ""
}

variable "cluster_name" {
  type        = string
  description = "The name of the Kubernetes cluster"
  default     = "kubernetes"
}

variable "cluster_api_addr" {
  type        = string
  description = "The IP address of the Kube API (VIP)"
}

variable "cluster_api_tls_sans" {
  type        = list(string)
  description = "Additional SANs to add to the Kube API cert"
  default     = []
}

variable "cluster_pod_cidr" {
  type        = string
  description = "The pod CIDR for the cluster"
  default     = "10.42.0.0/16"
}

variable "cluster_svc_cidr" {
  type        = string
  description = "The service CIDR for the cluster"
  default     = "10.43.0.0/16"
}

# ==============================================================================
# Gateway Setting
# ==============================================================================

variable "cluster_dns_gateway_addr" {
  type        = string
  description = "The Load balancer IP for k8s_gateway"
}

variable "cluster_gateway_addr" {
  type        = string
  description = "The Load balancer IP for the internal gateway"
}

variable "cloudflare_gateway_addr" {
  type        = string
  description = "The Load balancer IP for the external gateway"
}

# ==============================================================================
# GitHub
# ==============================================================================

variable "repository_name" {
  type        = string
  description = "GitHub repository (e.g. username/repo)"
}

variable "repository_branch" {
  type        = string
  description = "GitHub repository branch"
  default     = "main"
}

variable "repository_visibility" {
  type        = string
  description = "Repository visibility (public or private)"
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.repository_visibility)
    error_message = "repository_visibility must be either \"public\" or \"private\"."
  }
}

variable "github_deploy_key_file" {
  type        = string
  description = "Path to the file containing the GitHub deploy key"
  default     = "../secrets/github-deploy.key"
}

# ==============================================================================
# Cloudflare
# ==============================================================================

variable "cloudflare_domain" {
  type        = string
  description = "Domain you wish to use from your Cloudflare account"
}

variable "cloudflare_tunnel_file" {
  type        = string
  description = "Path to the JSON file containing Cloudflare tunnel credentials"
  default     = "../secrets/cloudflare-tunnel.json"

  validation {
    condition     = fileexists(var.cloudflare_tunnel_file)
    error_message = "cloudflare_tunnel_file must point to an existing Cloudflare tunnel credentials JSON file."
  }
}

variable "cloudflare_token" {
  type        = string
  description = "API Token for Cloudflare"
  sensitive   = true
  default     = ""
}

# ==============================================================================
# Cilium
# ==============================================================================

variable "cilium_loadbalancer_mode" {
  type        = string
  description = "The load balancer mode for cilium (dsr or snat)"
  default     = "dsr"

  validation {
    condition     = contains(["dsr", "snat"], var.cilium_loadbalancer_mode)
    error_message = "cilium_loadbalancer_mode must be either \"dsr\" or \"snat\"."
  }
}

variable "cilium_bgp_router_addr" {
  type        = string
  description = "The IP address of the BGP router"
  default     = ""
}

variable "cilium_bgp_router_asn" {
  type        = string
  description = "The BGP router ASN"
  default     = ""
}

variable "cilium_bgp_node_asn" {
  type        = string
  description = "The BGP node ASN"
  default     = ""
}

# ==============================================================================
# Security / Age
# ==============================================================================

variable "age_key_file" {
  type        = string
  description = "Path to the age.key file"
  default     = "../secrets/age.key"

  validation {
    condition     = fileexists(var.age_key_file)
    error_message = "age_key_file must point to an existing Age identity file."
  }
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to the kubeconfig file used by the Kubernetes and Helm providers for app bootstrap."
  default     = "../secrets/kubeconfig"
}

variable "kubernetes_api_addr" {
  type        = string
  description = "Reachable Kubernetes API address for Terraform and bootstrap operations. Defaults to the first control-plane node IP, which is safer than relying on the VIP during initial bootstrap."
  default     = ""
}

variable "gitops_local_path" {
  type        = string
  description = "Path to the local GitOps directory on disk."
  default     = "../../gitops"
}

variable "gitops_repo_path" {
  type        = string
  description = "Repository-relative path to the GitOps directory used by Argo CD."
  default     = "gitops"
}

# ==============================================================================
# Node Setting
# ==============================================================================

variable "controlplane_nodes" {
  description = "Map of Control Plane nodes. Must be an odd number (1, 3, 5, etc.) for HA etcd quorum."
  type = map(object({
    ip             = string
    install_disk   = string
    interface_mac  = string
    schematic_id   = string
    mtu            = optional(number, 1500)
    secureboot     = optional(bool, false)
    encrypt_disk   = optional(bool, false)
    kernel_modules = optional(list(string), [])
  }))

  validation {
    condition     = length(var.controlplane_nodes) >= 1
    error_message = "At least 1 control-plane node is required."
  }

  validation {
    condition     = length(var.controlplane_nodes) % 2 != 0
    error_message = "Control-plane node count must be odd (1, 3, 5, etc.) for etcd quorum. You provided ${length(var.controlplane_nodes)}."
  }
}

variable "worker_nodes" {
  description = "Map of Worker nodes"
  type = map(object({
    ip             = string
    install_disk   = string
    interface_mac  = string
    schematic_id   = string
    mtu            = optional(number, 1500)
    secureboot     = optional(bool, false)
    encrypt_disk   = optional(bool, false)
    kernel_modules = optional(list(string), [])
  }))
  default = {}
}
