##############################################################################
# variables.tf
##############################################################################

###############################################################################
# MinIO (S3 backend)
# minio_endpoint must match the endpoint passed during 'terraform init'.
# The bucket name is always equal to cluster_name.
###############################################################################

variable "minio_endpoint" {
  type        = string
  description = "MinIO S3-compatible endpoint URL (e.g. http://minio.local:9000)."
  default     = "http://minio.local:9000"
}

###############################################################################
# Passbolt connection
###############################################################################

variable "passbolt_url" {
  type        = string
  description = "Base URL of your self-hosted Passbolt instance."
  default     = "https://passbolt.example.com"
}

variable "passbolt_private_key" {
  type        = string
  description = "ASCII-armoured GPG private key for Passbolt auth. Set via TF_VAR_passbolt_private_key."
  sensitive   = true
  default     = ""
}

variable "passbolt_passphrase" {
  type        = string
  description = "Passphrase for the GPG private key. Set via TF_VAR_passbolt_passphrase."
  sensitive   = true
  default     = ""
}

variable "passbolt_resource_id_cluster_endpoint" {
  type        = string
  description = "Passbolt resource ID whose 'password' field holds the cluster API endpoint URL."
  default     = ""
}

###############################################################################
# Cluster identity
###############################################################################

variable "cluster_name" {
  type        = string
  description = "Cluster name used in talosconfig and kubeconfig."
  default     = "kubernetes"
}


variable "cluster_node_network" {
  type        = string
  description = "Subnet mask applied to every node's IP (e.g. /24)."
  default     = "/24"
}

variable "cluster_gateway" {
  type        = string
  description = "Network gateway applied to every node."
  default     = "192.168.8.1"
}

variable "cluster_vip" {
  type        = string
  description = "Layer-2 VIP injected natively onto all control-plane nodes."
  default     = "192.168.8.200"
}

variable "cluster_dns_servers" {
  type        = list(string)
  description = "DNS servers applied to every node."
  default     = ["1.1.1.1", "1.0.0.1"]
}

variable "cluster_ntp_servers" {
  type        = list(string)
  description = "NTP servers applied to every node."
  default     = ["162.159.200.1", "162.159.200.123"]
}

variable "cluster_api_tls_sans" {
  type        = list(string)
  description = "Optional additional SANs for the API server TLS certificate."
  default     = []
}

variable "cluster_pod_cidr" {
  type        = string
  description = "Pod network CIDR."
  default     = "10.42.0.0/16"
}

variable "cluster_svc_cidr" {
  type        = string
  description = "Service network CIDR."
  default     = "10.43.0.0/16"
}

###############################################################################
# Versions (Managed by Renovate)
# Do NOT override these in terraform.tfvars or you will break automatic updates!
###############################################################################

variable "talos_version" {
  type        = string
  description = "Talos OS version (e.g. v1.12.4)."
  # renovate: datasource=github-releases depName=siderolabs/talos
  default = "v1.12.4"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version (e.g. v1.35.2)."
  # renovate: datasource=github-releases depName=kubernetes/kubernetes
  default = "v1.35.2"
}

###############################################################################
# Control-plane nodes  (min 1, max N — validated below)
###############################################################################

variable "controlplane_nodes" {
  description = <<-DESC
    Map of control-plane nodes. Key = hostname.
    Must contain at least 1 node. For HA, use 3 or 5 (odd numbers for etcd quorum).
    Workers are defined separately in var.worker_nodes.
  DESC

  type = map(object({
    ip             = string
    install_disk   = string
    interface_mac  = string
    mtu            = number
    schematic_id   = string
    secureboot     = optional(bool, false)
    encrypt_disk   = optional(bool, false)
    kernel_modules = optional(list(string), [])
  }))

  default = {
    "home-lab" = {
      ip             = "192.168.8.2"
      install_disk   = "/dev/sdc"
      interface_mac  = "d8:5e:d3:0a:e9:75"
      mtu            = 1500
      schematic_id   = "1e17720baa2217bdf64a7caa256011144fce07af5dd12ce18baed735789e7c81"
      secureboot     = false
      encrypt_disk   = false
      kernel_modules = []
    }
  }

  validation {
    condition     = length(var.controlplane_nodes) >= 1
    error_message = "At least 1 control-plane node is required."
  }

  validation {
    condition     = length(var.controlplane_nodes) == 1 || length(var.controlplane_nodes) % 2 != 0
    error_message = "Control-plane node count must be odd (1, 3, 5, …) for etcd quorum. Got ${length(var.controlplane_nodes)}."
  }
}

###############################################################################
# Worker nodes  (min 0, max N)
###############################################################################

variable "worker_nodes" {
  description = <<-DESC
    Map of worker nodes. Key = hostname.
    Can be empty (single-node cluster where workloads run on the control-plane).
    Workers are scheduled on control-planes when this is empty because
    allowSchedulingOnControlPlanes = true is set in the controller patch.
  DESC

  type = map(object({
    ip             = string
    install_disk   = string
    interface_mac  = string
    mtu            = number
    schematic_id   = string
    secureboot     = optional(bool, false)
    encrypt_disk   = optional(bool, false)
    kernel_modules = optional(list(string), [])
  }))

  # Default: no dedicated workers (single-node home-lab setup)
  default = {}
}

###############################################################################
# Lifecycle operation flags
###############################################################################

variable "reset" {
  type        = bool
  description = "Trigger cluster factory reset."
  default     = false
}

variable "upgrade-k8s" {
  type        = bool
  description = "Trigger Kubernetes upgrade."
  default     = false
}

variable "upgrade-nodes" {
  type        = bool
  description = "Trigger Talos OS upgrade."
  default     = false
}
