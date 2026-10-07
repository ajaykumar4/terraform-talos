# Assign nodes to profiles matching their network interface MAC address
resource "matchbox_group" "nodes" {
  for_each = local.nodes_config

  name    = "${each.value.hostname}-${each.value.os_type}-${each.value.arch}"
  profile = matchbox_profile.nodes[each.key].name

  selector = {
    mac = each.value.mac
  }

  metadata = {
    hostname   = each.value.hostname
    arch       = each.value.arch
    os         = each.value.os_type
    os_version = each.value.os_version
  }
}