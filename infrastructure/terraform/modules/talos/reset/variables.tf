variable "client_configuration" { sensitive = true }
variable "controlplane_nodes" { type = map(any) }
variable "worker_nodes" { type = map(any) }