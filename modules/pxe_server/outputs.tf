output "systems_info" {
  description = "Information about systems configured for PXE boot"
  value = {
    total_systems = length(var.systems)
    talos_systems = [
      for s in var.systems : {
        name        = s.name
        os          = s.os
        mac_address = s.mac_address
        ip_address  = s.ip_address
      } if s.os == "talos"
    ]
    debian_systems = [
      for s in var.systems : {
        name        = s.name
        os          = s.os
        mac_address = s.mac_address
        ip_address  = s.ip_address
      } if s.os == "debian"
    ]
  }
}

output "container_info" {
  description = "Container configuration information"
  value = {
    runtime = "docker"
    image   = var.container_image
    ports = {
      dhcp = var.pxe_container_dhcp_port
      tftp = var.pxe_container_port
    }
  }
}

output "systems_manifest_path" {
  description = "Path to systems manifest file"
  value       = local_file.systems_manifest.filename
}

output "docker_compose_path" {
  description = "Path to docker-compose configuration"
  value       = local_file.docker_compose.filename
}

output "dhcp_hosts_config_path" {
  description = "Path to DHCP hosts configuration"
  value       = local_file.dhcp_hosts_config.filename
}

output "container_setup_guide" {
  description = "Guide for setting up containerized PXE server"
  value = <<-EOT
    ╔════════════════════════════════════════════════════════════╗
    │        CONTAINERIZED PXE SERVER SETUP                      │
    ╚════════════════════════════════════════════════════════════╝
    
    Container Runtime: docker
    Base Image: ${var.container_image}
    
    BUILD THE DOCKER IMAGE:
    
      1. Navigate to module directory:
         cd modules/pxe_server
    
      2. Build the image:
         docker build -t pxe-server:latest .
    
      3. Verify image:
         docker images | grep pxe-server
    
    START THE CONTAINER:
    
      Option A: Using docker-compose (Recommended)
        cd environments/home-lab
        docker-compose -f ../../modules/pxe_server/docker-compose.yml up -d
    
      Option B: Using docker run directly
        docker run -d \
          --name talos-pxe-server \
          --net host \
          -p 67:67/udp \
          -p 69:69/udp \
          -v ${var.pxe_root_path}:/var/lib/tftp:ro \
          -v ${local_file.dnsmasq_config.filename}:/config/dnsmasq.conf:ro \
          -v ${local_file.dhcp_hosts_config.filename}:/config/dhcp-hosts.conf:ro \
          pxe-server:latest
    
    VERIFY THE CONTAINER:
    
      1. Check if running:
         docker ps | grep pxe-server
    
      2. View logs:
         docker logs -f talos-pxe-server
    
      3. Test DHCP:
         docker exec talos-pxe-server dnsmasq --test
    
    STOP THE CONTAINER:
    
      docker stop talos-pxe-server
      docker rm talos-pxe-server
    
    ════════════════════════════════════════════════════════════
    SYSTEMS CONFIGURED (${length(var.systems)}):
    
    Talos Linux ${var.talos_version} (${var.talos_architecture}):
    %{~for s in [
  for sys in var.systems : sys if sys.os == "talos"
  ]~}
      • ${s.name}: MAC ${s.mac_address} → IP ${s.ip_address}
    %{~endfor~}
    
    Debian ${var.debian_version} (${var.debian_architecture}):
    %{~for s in [
  for sys in var.systems : sys if sys.os == "debian"
]~}
      • ${s.name}: MAC ${s.mac_address} → IP ${s.ip_address}
    %{~endfor~}
    ════════════════════════════════════════════════════════════
  EOT
}

output "pxe_server_status" {
  description = "Status information about PXE server"
  value = {
    configured        = true
    ip_address        = var.pxe_server_ip
    interface         = var.pxe_server_interface
    container_runtime = "docker"
  }
}

output "pxe_server_info" {
  description = "Detailed PXE server configuration"
  value = {
    server_ip         = var.pxe_server_ip
    interface         = var.pxe_server_interface
    dhcp_start        = var.dhcp_range_start
    dhcp_end          = var.dhcp_range_end
    dhcp_lease_time   = var.dhcp_lease_time
    subnet_mask       = var.subnet_mask
    gateway           = var.gateway
    dns_servers       = var.dns_servers
    root_directory    = var.pxe_root_path
    container_enabled = true
    container_runtime = "docker"
  }
}

output "dnsmasq_config_path" {
  description = "Path to generated dnsmasq configuration file"
  value       = local_file.dnsmasq_config.filename
}

output "boot_script_path" {
  description = "Path to generated iPXE boot script"
  value       = local_file.boot_ipxe_script.filename
}

output "talos_boot_info" {
  description = "Talos Linux boot information"
  value = var.enable_talos ? {
    enabled        = true
    version        = var.talos_version
    architecture   = var.talos_architecture
    kernel_url     = local.talos_boot_urls.kernel
    initrd_url     = local.talos_boot_urls.initrd
    kernel_cmdline = var.talos_kernel_cmdline
    systems_count  = length([for s in var.systems : s if s.os == "talos"])
    } : {
    enabled = false
  }
}

output "debian_boot_info" {
  description = "Debian Linux boot information"
  value = var.enable_debian ? {
    enabled        = true
    version        = var.debian_version
    architecture   = var.debian_architecture
    kernel_url     = local.debian_boot_urls.kernel
    initrd_url     = local.debian_boot_urls.initrd
    kernel_cmdline = var.debian_kernel_cmdline
    systems_count  = length([for s in var.systems : s if s.os == "debian"])
    } : {
    enabled = false
  }
}

output "file_paths" {
  description = "Important file paths for reference"
  value = {
    dnsmasq_config    = local_file.dnsmasq_config.filename
    dhcp_hosts_config = local_file.dhcp_hosts_config.filename
    systems_manifest  = local_file.systems_manifest.filename
    boot_script       = local_file.boot_ipxe_script.filename
    docker_compose    = local_file.docker_compose.filename
    dockerfile        = local_file.dockerfile.filename
    pxe_root          = var.pxe_root_path
  }
}

output "setup_instructions" {
  description = "Instructions to set up the PXE server on macOS"
  value       = <<-EOT
    PXE Server Configuration Generated Successfully!
    
    ┌────────────────────────────────────────────────────────────┐
    │              CONTAINERIZED PXE SERVER SETUP                │
    └────────────────────────────────────────────────────────────┘
    
    1. BUILD DOCKER IMAGE:
       cd modules/pxe_server
       docker build -t pxe-server:latest .
    
    2. VERIFY BUILD:
       docker images | grep pxe-server
    
    3. START CONTAINER:
       docker-compose -f docker-compose.yml up -d
    
    4. VERIFY SERVICES:
       docker ps | grep pxe-server
       docker logs -f talos-pxe-server
    
    5. CONFIGURE SYSTEMS:
       Edit terraform.tfvars to add/remove systems
       Update systems[] configuration
    
    6. DOWNLOAD BOOT FILES:
       talosctl download vmlinuz-amd64
       talosctl download initramfs-amd64.xz
  EOT
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    NEXT STEPS:
    
    1. BUILD AND START CONTAINER:
       docker build -t pxe-server modules/pxe_server/
       docker run -d --name talos-pxe --net host -v ${var.pxe_root_path}:/var/lib/tftp pxe-server
    
    2. VERIFY CONTAINER:
       docker ps | grep pxe-server
       docker logs talos-pxe-server
    
    3. CONFIGURE BOOT FILES:
       Place boot files in:
       - ${var.pxe_root_path}/talos/
       - ${var.pxe_root_path}/debian/
    
    4. BOOT SYSTEMS:
       Available boot options:
       %{~for s in var.systems~}
       • ${s.name}: ${s.os} @ ${s.ip_address} (MAC: ${s.mac_address})
       %{~endfor~}
    
    5. MONITOR:
       docker logs -f talos-pxe-server
       docker exec talos-pxe-server dnsmasq --test
    
    SYSTEMS CONFIGURED:
    Total: ${length(var.systems)}
    - Talos: ${length([for s in var.systems : s if s.os == "talos"])}
    - Debian: ${length([for s in var.systems : s if s.os == "debian"])}
  EOT
}
