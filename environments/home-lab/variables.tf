variable "pxe_server_ip" {
  description = "IP address of the PXE server (this macbook)"
  type        = string
  default     = "192.168.1.100"
}

variable "pxe_server_interface" {
  description = "Network interface for PXE server (e.g., en0, en1)"
  type        = string
  default     = "en0"
}

variable "pxe_root_path" {
  description = "Root path for PXE files on the server"
  type        = string
  default     = "/var/lib/tftp"
}

variable "dhcp_range_start" {
  description = "Start of DHCP range for PXE clients"
  type        = string
  default     = "192.168.1.200"
}

variable "dhcp_range_end" {
  description = "End of DHCP range for PXE clients"
  type        = string
  default     = "192.168.1.250"
}

variable "dhcp_lease_time" {
  description = "DHCP lease time in seconds"
  type        = number
  default     = 3600
}

variable "talos_version" {
  description = "Talos Linux version to use"
  type        = string
  default     = "v1.14.2"
}

variable "talos_architecture" {
  description = "Talos Linux architecture (amd64 or arm64)"
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.talos_architecture)
    error_message = "Architecture must be amd64 or arm64."
  }
}

variable "debian_version" {
  description = "Debian Linux version to use (e.g., 13.7, trixie)"
  type        = string
  default     = "13.7"
}

variable "debian_architecture" {
  description = "Debian Linux architecture (amd64 or arm64)"
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.debian_architecture)
    error_message = "Architecture must be amd64 or arm64."
  }
}

variable "enable_talos" {
  description = "Enable Talos Linux PXE boot option"
  type        = bool
  default     = true
}

variable "enable_debian" {
  description = "Enable Debian Linux PXE boot option"
  type        = bool
  default     = true
}

variable "boot_menu_timeout" {
  description = "Timeout for boot menu in seconds (0 = no timeout)"
  type        = number
  default     = 30
}

variable "container_runtime" {
  description = "Container runtime to use (docker, podman, auto)"
  type        = string
  default     = "auto"
  validation {
    condition     = contains(["docker", "podman", "auto"], var.container_runtime)
    error_message = "Container runtime must be docker, podman, or auto."
  }
}

variable "container_image" {
  description = "Base container image for PXE server"
  type        = string
  default     = "alpine:latest"
}

variable "pxe_container_port" {
  description = "Container port for TFTP (69)"
  type        = number
  default     = 69
}

variable "pxe_container_dhcp_port" {
  description = "Container port for DHCP (67)"
  type        = number
  default     = 67
}

variable "systems" {
  description = "List of systems to boot via PXE"
  type = list(object({
    name         = string
    os           = string
    architecture = string
    mac_address  = string
    ip_address   = string
  }))
  default = [
    {
      name         = "node1"
      os           = "talos"
      architecture = "amd64"
      mac_address  = "52:54:00:12:34:01"
      ip_address   = "192.168.8.101"
    },
    {
      name         = "node2"
      os           = "talos"
      architecture = "amd64"
      mac_address  = "52:54:00:12:34:02"
      ip_address   = "192.168.8.102"
    },
    {
      name         = "nas1"
      os           = "debian"
      architecture = "amd64"
      mac_address  = "52:54:00:12:34:10"
      ip_address   = "192.168.8.110"
    },
    {
      name         = "nas2"
      os           = "debian"
      architecture = "amd64"
      mac_address  = "52:54:00:12:34:11"
      ip_address   = "192.168.8.111"
    }
  ]
}

variable "macos_user" {
  description = "macOS username for local operations"
  type        = string
  default     = "ajay.kumar"
}

variable "enable_talos_installer" {
  description = "Enable automated Talos installer via iPXE"
  type        = bool
  default     = true
}

variable "enable_debian_installer" {
  description = "Enable automated Debian installer via iPXE"
  type        = bool
  default     = true
}

variable "talos_kernel_cmdline" {
  description = "Additional kernel command line parameters for Talos"
  type        = string
  default     = "console=tty0 console=ttyS0"
}

variable "debian_kernel_cmdline" {
  description = "Additional kernel command line parameters for Debian"
  type        = string
  default     = "console=tty0 console=ttyS0"
}

variable "subnet_mask" {
  description = "Network subnet mask"
  type        = string
  default     = "255.255.255.0"
}

variable "gateway" {
  description = "Network gateway address"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_servers" {
  description = "DNS servers for clients"
  type        = list(string)
  default     = ["8.8.8.8", "8.8.4.4"]
}
