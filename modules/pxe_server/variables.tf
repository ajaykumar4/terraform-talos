variable "pxe_server_ip" {
  description = "IP address of the PXE server"
  type        = string
}

variable "pxe_server_interface" {
  description = "Network interface for PXE server"
  type        = string
}

variable "pxe_root_path" {
  description = "Root path for PXE files"
  type        = string
  default     = "/var/lib/tftp"
}

variable "dhcp_range_start" {
  description = "Start of DHCP range"
  type        = string
}

variable "dhcp_range_end" {
  description = "End of DHCP range"
  type        = string
}

variable "dhcp_lease_time" {
  description = "DHCP lease time in seconds"
  type        = number
  default     = 3600
}

variable "subnet_mask" {
  description = "Network subnet mask"
  type        = string
  default     = "255.255.255.0"
}

variable "gateway" {
  description = "Network gateway address"
  type        = string
}

variable "dns_servers" {
  description = "DNS servers for DHCP clients"
  type        = list(string)
}

variable "talos_version" {
  description = "Talos Linux version"
  type        = string
}

variable "talos_architecture" {
  description = "Talos Linux architecture"
  type        = string
  default     = "amd64"
}

variable "talos_kernel_cmdline" {
  description = "Additional kernel parameters for Talos"
  type        = string
  default     = "console=tty0 console=ttyS0"
}

variable "enable_talos" {
  description = "Enable Talos Linux boot option"
  type        = bool
  default     = true
}

variable "debian_version" {
  description = "Debian Linux version"
  type        = string
}

variable "debian_architecture" {
  description = "Debian Linux architecture"
  type        = string
  default     = "amd64"
}

variable "debian_kernel_cmdline" {
  description = "Additional kernel parameters for Debian"
  type        = string
  default     = "console=tty0 console=ttyS0"
}

variable "enable_debian" {
  description = "Enable Debian Linux boot option"
  type        = bool
  default     = true
}

variable "boot_menu_timeout" {
  description = "Boot menu timeout in seconds"
  type        = number
  default     = 30
}

variable "enable_talos_installer" {
  description = "Enable automated Talos installer"
  type        = bool
  default     = true
}

variable "enable_debian_installer" {
  description = "Enable automated Debian installer"
  type        = bool
  default     = true
}

variable "container_runtime" {
  description = "Container runtime to use (container, docker, podman, auto)"
  type        = string
  default     = "auto"

  validation {
    condition     = contains(["container", "docker", "podman", "auto"], var.container_runtime)
    error_message = "container_runtime must be one of: container, docker, podman, or auto"
  }
}

variable "container_image" {
  description = "Base container image for PXE server"
  type        = string
  default     = "alpine:latest"
}

variable "pxe_container_port" {
  description = "Container port for TFTP"
  type        = number
  default     = 69
}

variable "pxe_container_dhcp_port" {
  description = "Container port for DHCP"
  type        = number
  default     = 67
}

variable "systems" {
  description = "List of systems to boot via PXE"
  type = list(object({
    name        = string
    os          = string
    mac_address = string
    ip_address  = string
  }))
  default = []
}

variable "macos_user" {
  description = "macOS username for operations"
  type        = string
}
