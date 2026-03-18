resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for _, node in var.controlplane_nodes : node.ip]
  nodes                = [for _, node in merge(var.controlplane_nodes, var.worker_nodes) : node.ip]
}

# Saves talosconfig to the local secrets directory automatically
resource "local_sensitive_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.root}/../secrets/talosconfig"
}
