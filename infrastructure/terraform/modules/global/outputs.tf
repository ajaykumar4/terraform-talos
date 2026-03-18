output "client_configuration" { value = talos_machine_secrets.this.client_configuration }
output "machine_secrets" { value = talos_machine_secrets.this.machine_secrets }
output "node_images" { value = local.node_images }
output "common_machine_patches" { value = local.common_machine_patches }
output "controller_patches" { value = local.controller_patches }