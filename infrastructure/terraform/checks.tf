locals {
  node_cidr_base_ip = split("/", var.node_cidr)[0]
  node_cidr_prefix  = tonumber(split("/", var.node_cidr)[1])
  node_cidr_block   = pow(2, 32 - local.node_cidr_prefix)

  node_cidr_network_key = floor(
    (
      tonumber(split(".", local.node_cidr_base_ip)[0]) * 16777216 +
      tonumber(split(".", local.node_cidr_base_ip)[1]) * 65536 +
      tonumber(split(".", local.node_cidr_base_ip)[2]) * 256 +
      tonumber(split(".", local.node_cidr_base_ip)[3])
    ) / local.node_cidr_block
  )

  node_network_addresses = merge(
    {
      for name, node in var.controlplane_nodes :
      "controlplane_nodes.${name}.ip" => node.ip
    },
    {
      for name, node in var.worker_nodes :
      "worker_nodes.${name}.ip" => node.ip
    },
    {
      cluster_api_addr         = var.cluster_api_addr
      cluster_dns_gateway_addr = var.cluster_dns_gateway_addr
      cluster_gateway_addr     = var.cluster_gateway_addr
      cloudflare_gateway_addr  = var.cloudflare_gateway_addr
    }
  )

  node_cidr_outside_addresses = [
    for label, ip in local.node_network_addresses : "${label}=${ip}"
    if !(
      length(split(".", ip)) == 4 &&
      alltrue([
        for octet in split(".", ip) :
        can(tonumber(octet)) && tonumber(octet) >= 0 && tonumber(octet) <= 255
      ]) &&
      floor(
        (
          tonumber(split(".", ip)[0]) * 16777216 +
          tonumber(split(".", ip)[1]) * 65536 +
          tonumber(split(".", ip)[2]) * 256 +
          tonumber(split(".", ip)[3])
        ) / local.node_cidr_block
      ) == local.node_cidr_network_key
    )
  ]
}

resource "terraform_data" "input_validation" {
  input = local.node_network_addresses

  lifecycle {
    precondition {
      condition     = length(local.node_cidr_outside_addresses) == 0
      error_message = "All node, API VIP, and gateway addresses must belong to node_cidr (${var.node_cidr}). Fix these values: ${join(", ", local.node_cidr_outside_addresses)}"
    }
  }
}
