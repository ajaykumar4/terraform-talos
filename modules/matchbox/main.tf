locals {
  # Resolve OS version based on OS type
  os_version = var.os_type == "talos" ? var.talos_version : var.debian_version

  # Assets directory paths
  kernel_path = var.os_type == "talos" ? "/assets/talos/${var.talos_version}/${var.arch}/vmlinuz" : "/assets/debian/${var.debian_version}/${var.arch}/linux"
  initrd_path = var.os_type == "talos" ? "/assets/talos/${var.talos_version}/${var.arch}/initramfs.xz" : "/assets/debian/${var.debian_version}/${var.arch}/initrd.gz"

  # Dynamic preseed filename for Debian nodes
  preseed_filename = "preseed-${var.hostname}.cfg"

  debian_args = [
    "initrd=initrd.gz",
    "auto=true",
    "priority=critical",
    "url=${var.matchbox_http_endpoint}/assets/${local.preseed_filename}",
    "interface=auto",
    "netcfg/dhcp_timeout=60"
  ]

  talos_args = [
    "initrd=initramfs.xz",
    "talos.platform=metal",
    "talos.config=${var.matchbox_http_endpoint}/assets/talos-controlplane.yaml",
    "slab_nomerge",
    "pti=on",
    "console=tty0"
  ]
}

# --- Dynamic Debian Preseed Generation ---
resource "local_file" "debian_preseed" {
  count = var.os_type == "debian" ? 1 : 0

  filename = "${pathexpand(var.matchbox_assets_path)}/${local.preseed_filename}"

  content = templatefile("${path.module}/../../templates/debian-preseed.cfg.tftpl", {
    hostname      = var.hostname
    root_password = var.debian_root_password
    os_version    = var.debian_version
    arch          = var.arch
  })
}

# --- Matchbox Profile ---
resource "matchbox_profile" "node_profile" {
  name   = "${var.hostname}-${var.os_type}-${var.arch}"
  kernel = local.kernel_path
  initrd = [local.initrd_path]
  args   = var.os_type == "talos" ? local.talos_args : local.debian_args

  depends_on = [local_file.debian_preseed]
}

# --- Matchbox Machine Group ---
resource "matchbox_group" "node_group" {
  name    = "${var.hostname}-${var.os_type}-${var.arch}"
  profile = matchbox_profile.node_profile.name

  selector = {
    mac = lower(var.mac)
  }

  metadata = {
    hostname   = var.hostname
    arch       = var.arch
    os         = var.os_type
    os_version = local.os_version
  }
}