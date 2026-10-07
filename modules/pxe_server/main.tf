# Versions and providers defined in versions.tf

# Detect container runtime availability
resource "local_file" "dnsmasq_config" {
  content = templatefile("${path.module}/templates/dnsmasq.conf.tftpl", {
    interface        = var.pxe_server_interface
    pxe_server_ip    = var.pxe_server_ip
    dhcp_range_start = var.dhcp_range_start
    dhcp_range_end   = var.dhcp_range_end
    dhcp_lease_time  = var.dhcp_lease_time
    subnet_mask      = var.subnet_mask
    gateway          = var.gateway
    dns_servers      = var.dns_servers
    pxe_root_path    = var.pxe_root_path
  })
  filename = "${var.pxe_root_path}/dnsmasq.conf"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Generate main iPXE boot menu
resource "local_file" "boot_ipxe_script" {
  content = templatefile("${path.module}/templates/boot.ipxe.tftpl", {
    pxe_server_ip           = var.pxe_server_ip
    boot_menu_timeout       = var.boot_menu_timeout
    enable_talos            = var.enable_talos
    enable_debian           = var.enable_debian
    talos_version           = var.talos_version
    talos_architecture      = var.talos_architecture
    talos_kernel_cmdline    = var.talos_kernel_cmdline
    debian_version          = var.debian_version
    debian_architecture     = var.debian_architecture
    debian_kernel_cmdline   = var.debian_kernel_cmdline
    enable_talos_installer  = var.enable_talos_installer
    enable_debian_installer = var.enable_debian_installer
  })
  filename = "${var.pxe_root_path}/boot.ipxe"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Generate OS-specific boot templates for extensibility
resource "local_file" "talos_ipxe_script" {
  content = templatefile("${path.module}/templates/talos.ipxe.tftpl", {
    pxe_server_ip          = var.pxe_server_ip
    talos_version          = var.talos_version
    talos_architecture     = var.talos_architecture
    talos_kernel_cmdline   = var.talos_kernel_cmdline
    enable_talos_installer = var.enable_talos_installer
  })
  filename = "${var.pxe_root_path}/talos.ipxe"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

resource "local_file" "debian_ipxe_script" {
  content = templatefile("${path.module}/templates/debian.ipxe.tftpl", {
    pxe_server_ip           = var.pxe_server_ip
    debian_version          = var.debian_version
    debian_architecture     = var.debian_architecture
    debian_kernel_cmdline   = var.debian_kernel_cmdline
    enable_debian_installer = var.enable_debian_installer
  })
  filename = "${var.pxe_root_path}/debian.ipxe"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Ensure PXE root directory exists
resource "local_file" "pxe_root_directory" {
  content  = "# PXE Boot Root Directory\n"
  filename = "${var.pxe_root_path}/.terraform-managed"
}

# Generate Talos boot URLs
locals {
  talos_release_url = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}"

  talos_boot_urls = var.enable_talos ? {
    kernel = "${local.talos_release_url}/vmlinuz-${var.talos_architecture}"
    initrd = "${local.talos_release_url}/initramfs-${var.talos_architecture}.xz"
  } : {}

  debian_boot_urls = var.enable_debian ? {
    kernel = "https://deb.debian.org/debian/dists/${var.debian_version}/main/installer-${var.debian_architecture}/current/images/netboot/debian-installer/${var.debian_architecture}/linux"
    initrd = "https://deb.debian.org/debian/dists/${var.debian_version}/main/installer-${var.debian_architecture}/current/images/netboot/debian-installer/${var.debian_architecture}/initrd.gz"
  } : {}

  # Container runtime detection
  container_runtime = var.container_runtime == "auto" ? (
    fileexists("/opt/homebrew/bin/container") ? "container" :
    fileexists("/var/run/docker.sock") ? "docker" :
    fileexists("/run/podman/podman.sock") ? "podman" :
    "container"
  ) : var.container_runtime

  # System configurations indexed by MAC address
  systems_by_mac = {
    for system in var.systems : system.mac_address => system
  }

  # Talos systems
  talos_systems = [
    for system in var.systems : system if system.os == "talos"
  ]

  # Debian systems
  debian_systems = [
    for system in var.systems : system if system.os == "debian"
  ]
}

# Generate Dockerfile for PXE server container
resource "local_file" "dockerfile" {
  content = templatefile("${path.module}/templates/Dockerfile.tftpl", {
    base_image = var.container_image
  })
  filename = "${path.module}/Dockerfile"
}

# Generate dnsmasq container startup script
resource "local_file" "container_entrypoint" {
  content = templatefile("${path.module}/templates/entrypoint.sh.tftpl", {
    pxe_root_path = var.pxe_root_path
  })
  filename = "${path.module}/entrypoint.sh"
}

# Generate systems manifest
resource "local_file" "systems_manifest" {
  content = jsonencode({
    timestamp = timestamp()
    systems = {
      total  = length(var.systems)
      talos  = length(local.talos_systems)
      debian = length(local.debian_systems)
    }
    system_details = [
      for system in var.systems : {
        name        = system.name
        os          = system.os
        mac_address = system.mac_address
        ip_address  = system.ip_address
      }
    ]
    boot_info = {
      talos  = local.talos_boot_urls
      debian = local.debian_boot_urls
    }
  })
  filename = "${var.pxe_root_path}/.systems-manifest.json"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Generate DHCP host configurations for static IPs
resource "local_file" "dhcp_hosts_config" {
  content = join("\n", [
    for system in var.systems : "dhcp-host=${system.mac_address},${system.ip_address},${system.name},1h"
  ])
  filename = "${var.pxe_root_path}/dhcp-hosts.conf"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Generate container compose file
resource "local_file" "docker_compose" {
  content = templatefile("${path.module}/templates/docker-compose.yml.tftpl", {
    container_runtime       = local.container_runtime
    pxe_server_ip           = var.pxe_server_ip
    pxe_root_path           = var.pxe_root_path
    pxe_container_port      = var.pxe_container_port
    pxe_container_dhcp_port = var.pxe_container_dhcp_port
    dhcp_hosts_config       = local_file.dhcp_hosts_config.filename
    dnsmasq_config          = local_file.dnsmasq_config.filename
  })
  filename = "${path.module}/docker-compose.yml"

  depends_on = [
    local_file.pxe_root_directory,
    local_file.dnsmasq_config,
    local_file.dhcp_hosts_config
  ]
}
