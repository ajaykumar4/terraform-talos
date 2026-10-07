# Render dynamic preseed configs only for nodes running Debian
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