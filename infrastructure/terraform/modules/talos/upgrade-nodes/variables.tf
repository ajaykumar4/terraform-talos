variable "client_configuration" { sensitive = true }
variable "talos_version" {}
variable "controlplane_nodes" { type = map(any) }
variable "worker_nodes" { type = map(any) }
variable "node_images" { type = map(string) }