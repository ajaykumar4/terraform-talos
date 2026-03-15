##############################################################################
# outputs.tf
##############################################################################

###############################################################################
# Local File Exports
# Automatically writes credentials to your local ~/.talos and ~/.kube directories
# natively during terraform apply.
###############################################################################

resource "local_sensitive_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = pathexpand("~/.talos/config")
}

resource "local_sensitive_file" "kubeconfig" {
  content  = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = pathexpand("~/.kube/config")
}

###############################################################################
# CLI Outputs
###############################################################################

output "talosconfig" {
  description = "talosconfig file content. (This is also written to ~/.talos/config automatically)."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "kubeconfig file content. (This is also written to ~/.kube/config automatically)."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}
output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "controlplane_ips" {
  description = "IP addresses of all control-plane nodes."
  value       = { for k, v in local.controlplane_nodes : k => v.ip }
}

output "worker_ips" {
  description = "IP addresses of all worker nodes."
  value       = { for k, v in local.worker_nodes : k => v.ip }
}

output "passbolt_talosconfig_id" {
  description = "Passbolt entry ID for the talosconfig."
  value       = passbolt_password.talosconfig.id
}

output "passbolt_kubeconfig_id" {
  description = "Passbolt entry ID for the kubeconfig."
  value       = passbolt_password.kubeconfig.id
}

output "passbolt_machine_secrets_id" {
  description = "Passbolt entry ID for the machine secrets."
  value       = passbolt_password.machine_secrets.id
}
