variable "client_configuration" { sensitive = true }
variable "kubernetes_version" {}
variable "controlplane_nodes" { type = map(any) }
variable "worker_nodes" { type = map(any) }