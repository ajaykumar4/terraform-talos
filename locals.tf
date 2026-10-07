locals {
  # Standardize inventory inputs, asset paths, and kernel boot flags
  nodes_config = {
    for k, v in var.nodes : k => {
      hostname         = v.hostname
      mac              = lower(v.mac)
      arch             = lower(v.arch)
      os_type          = lower(v.os)
      os_version       = lower(v.os) == "talos" ? var.talos_version : var.debian_version
      preseed_filename = "preseed-${v.hostname}.cfg"

      # Kernel and initrd paths served by Matchbox asset container
      kernel_path = lower(v.os) == "talos" ? "/assets/talos/${var.talos_version}/${lower(v.arch)}/vmlinuz" : "/assets/debian/${var.debian_version}/${lower(v.arch)}/linux"
      initrd_path = lower(v.os) == "talos" ? "/assets/talos/${var.talos_version}/${lower(v.arch)}/initramfs.xz" : "/assets/debian/${var.debian_version}/${lower(v.arch)}/initrd.gz"

      # Kernel Arguments
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

  # Filtered inventory containing only Debian nodes for template generation
  debian_nodes = {
    for k, v in local.nodes_config : k => v if v.os_type == "debian"
  }
}