provider "matchbox" {
  endpoint = var.matchbox_rpc_endpoint
}

locals {
  # Normalize nodes and determine paths/arguments dynamically
  nodes_config = {
    for k, v in var.nodes : k => {
      hostname         = v.hostname
      mac              = lower(v.mac)
      arch             = lower(v.arch)
      os_type          = lower(v.os)
      os_version       = lower(v.os) == "talos" ? var.talos_version : var.debian_version
      preseed_filename = "preseed-${v.hostname}.cfg"

      # Asset paths
      kernel_path = lower(v.os) == "talos" ? "/assets/talos/${var.talos_version}/${lower(v.arch)}/vmlinuz" : "/assets/debian/${var.debian_version}/${lower(v.arch)}/linux"
      initrd_path = lower(v.os) == "talos" ? "/assets/talos/${var.talos_version}/${lower(v.arch)}/initramfs.xz" : "/assets/debian/${var.debian_version}/${lower(v.arch)}/initrd.gz"

      # Kernel Boot Parameters
      kernel_args = lower(v.os) == "talos" ? [
        "initrd=initramfs.xz",
        "talos.platform=metal",
        "talos.config=${var.matchbox_http_endpoint}/assets/talos-controlplane.yaml",
        "slab_nomerge",
        "pti=on",
        "console=tty0"
      ] : [
        "initrd=initrd.gz",
        "auto=true",
        "priority=critical",
        "url=${var.matchbox_http_endpoint}/assets/preseed-${v.hostname}.cfg",
        "interface=auto",
        "netcfg/dhcp_timeout=60"
      ]
    }
  }

  # Filter only Debian nodes for preseed generation
  debian_nodes = {
    for k, v in local.nodes_config : k => v if v.os_type == "debian"
  }
}

# --- 1. Dynamic Debian Preseed Generation ---
resource "local_file" "debian_preseed" {
  for_each = local.debian_nodes

  filename = "${pathexpand(var.matchbox_assets_path)}/${each.value.preseed_filename}"

  content = templatefile("${path.module}/templates/debian-preseed.cfg.tftpl", {
    hostname      = each.value.hostname
    root_password = var.debian_root_password
    os_version    = var.debian_version
    arch          = each.value.arch
  })
}

# --- 2. Matchbox Profiles ---
resource "matchbox_profile" "nodes" {
  for_each = local.nodes_config

  name   = "${each.value.hostname}-${each.value.os_type}-${each.value.arch}"
  kernel = each.value.kernel_path
  initrd = [each.value.initrd_path]
  args   = each.value.kernel_args

  depends_on = [local_file.debian_preseed]
}

# --- 3. Matchbox Machine Groups ---
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