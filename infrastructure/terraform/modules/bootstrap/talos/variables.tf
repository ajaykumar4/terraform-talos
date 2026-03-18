variable "client_configuration" { sensitive = true }
variable "machine_secrets" { sensitive = true }
variable "talos_version" { type = string }
variable "kubernetes_version" { type = string }
variable "cluster_name" { type = string }
variable "cluster_api_addr" { type = string }
variable "bootstrap_generation" { type = number }
variable "kubernetes_api_addr" { type = string }
variable "node_cidr" { type = string }
variable "node_default_gateway" { type = string }
variable "node_vlan_tag" { type = string }

# Injected from global module
variable "node_images" { type = map(string) }
variable "common_machine_patches" { type = list(string) }
variable "controller_patches" { type = list(string) }

variable "controlplane_nodes" {
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
}

variable "worker_nodes" {
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
}
