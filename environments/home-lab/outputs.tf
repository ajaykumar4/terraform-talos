output "pxe_server_status" {
  description = "Status of the PXE server"
  value       = module.pxe_server.pxe_server_status
}

output "pxe_server_info" {
  description = "PXE server configuration details"
  value       = module.pxe_server.pxe_server_info
}

output "systems_info" {
  description = "Information about configured systems"
  value       = module.pxe_server.systems_info
}

output "container_info" {
  description = "Container runtime information"
  value       = module.pxe_server.container_info
}

output "dnsmasq_config_path" {
  description = "Path to generated dnsmasq configuration"
  value       = module.pxe_server.dnsmasq_config_path
}

output "boot_script_path" {
  description = "Path to generated iPXE boot script"
  value       = module.pxe_server.boot_script_path
}

output "dhcp_hosts_config_path" {
  description = "Path to DHCP hosts configuration"
  value       = module.pxe_server.dhcp_hosts_config_path
}

output "systems_manifest_path" {
  description = "Path to systems manifest"
  value       = module.pxe_server.systems_manifest_path
}

output "docker_compose_path" {
  description = "Path to docker-compose file"
  value       = module.pxe_server.docker_compose_path
}

output "talos_boot_info" {
  description = "Talos Linux boot information"
  value       = module.pxe_server.talos_boot_info
}

output "debian_boot_info" {
  description = "Debian Linux boot information"
  value       = module.pxe_server.debian_boot_info
}

output "container_setup_guide" {
  description = "Guide for containerized PXE server setup"
  value       = module.pxe_server.container_setup_guide
}

output "setup_instructions" {
  description = "Instructions to set up the PXE server"
  value       = module.pxe_server.setup_instructions
}

output "next_steps" {
  description = "Next steps after applying this configuration"
  value       = module.pxe_server.next_steps
}

output "file_paths" {
  description = "Important file paths for reference"
  value       = module.pxe_server.file_paths
}
