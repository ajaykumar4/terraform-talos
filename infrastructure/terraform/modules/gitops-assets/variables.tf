variable "gitops_local_path" { type = string }

variable "cloudflare_domain" { type = string }
variable "cloudflare_token" {
  type      = string
  sensitive = true
}
variable "cloudflare_tunnel_id" { type = string }
variable "cloudflare_tunnel_token" {
  type      = string
  sensitive = true
}

variable "cluster_dns_gateway_addr" { type = string }
variable "cluster_gateway_addr" { type = string }
variable "cloudflare_gateway_addr" { type = string }

variable "node_cidr" { type = string }
variable "cluster_pod_cidr" { type = string }
variable "cilium_bgp_enabled" { type = bool }
variable "cilium_bgp_router_addr" { type = string }
variable "cilium_bgp_router_asn" { type = string }
variable "cilium_bgp_node_asn" { type = string }

variable "age_public_key" { type = string }
