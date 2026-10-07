terraform {
  required_version = ">= 1.5"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "local" {}

# Docker provider with optional error handling
provider "docker" {
  # Auto-detect Docker daemon socket
}

module "pxe_server" {
  source = "../../modules/pxe_server"

  # PXE Server Configuration
  pxe_server_ip        = var.pxe_server_ip
  pxe_server_interface = var.pxe_server_interface
  pxe_root_path        = var.pxe_root_path

  # DHCP Configuration
  dhcp_range_start = var.dhcp_range_start
  dhcp_range_end   = var.dhcp_range_end
  dhcp_lease_time  = var.dhcp_lease_time
  subnet_mask      = var.subnet_mask
  gateway          = var.gateway
  dns_servers      = var.dns_servers

  # Talos Linux Configuration
  talos_version        = var.talos_version
  talos_architecture   = var.talos_architecture
  enable_talos         = var.enable_talos
  talos_kernel_cmdline = var.talos_kernel_cmdline

  # Debian Linux Configuration
  debian_version        = var.debian_version
  debian_architecture   = var.debian_architecture
  enable_debian         = var.enable_debian
  debian_kernel_cmdline = var.debian_kernel_cmdline

  # Boot Configuration
  boot_menu_timeout       = var.boot_menu_timeout
  enable_talos_installer  = var.enable_talos_installer
  enable_debian_installer = var.enable_debian_installer

  # Container Configuration
  container_runtime       = var.container_runtime
  container_image         = var.container_image
  pxe_container_port      = var.pxe_container_port
  pxe_container_dhcp_port = var.pxe_container_dhcp_port

  # Systems Configuration
  systems = var.systems

  # System Configuration
  macos_user = var.macos_user
}
