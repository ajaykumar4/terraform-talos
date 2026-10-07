# Asset management for PXE server
# This file manages asset directories and metadata

locals {
  # Asset directories
  pxe_asset_dirs = [
    "${var.pxe_root_path}",
    "${var.pxe_root_path}/talos",
    "${var.pxe_root_path}/debian",
    "${var.pxe_root_path}/efi",
    "${var.pxe_root_path}/scripts"
  ]

  # Talos Linux assets
  talos_assets = var.enable_talos ? {
    version      = var.talos_version
    architecture = var.talos_architecture
    kernel_name  = "vmlinuz-${var.talos_architecture}"
    initrd_name  = "initramfs-${var.talos_architecture}.xz"
    release_url  = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}"
  } : {}

  # Debian Linux assets
  debian_assets = var.enable_debian ? {
    version      = var.debian_version
    architecture = var.debian_architecture
    kernel_name  = "linux"
    initrd_name  = "initrd.gz"
    base_url     = "https://deb.debian.org/debian/dists/${var.debian_version}/main/installer-${var.debian_architecture}/current/images/netboot/debian-installer/${var.debian_architecture}"
  } : {}

  # Asset manifest
  assets_manifest = {
    talos  = local.talos_assets
    debian = local.debian_assets
  }
}

# Create manifest file for asset tracking
resource "local_file" "assets_manifest" {
  content  = jsonencode(local.assets_manifest)
  filename = "${var.pxe_root_path}/.assets-manifest.json"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Create subdirectory structure
resource "local_file" "asset_directories" {
  for_each = toset(local.pxe_asset_dirs)

  content  = "# Asset directory managed by Terraform\n"
  filename = "${each.value}/.keep"

  depends_on = [
    local_file.pxe_root_directory
  ]
}

# Download status tracker
resource "local_file" "download_status" {
  content = <<-EOT
    # Asset Download Status
    
    Generated: ${timestamp()}
    
    Talos Linux:
    %{if var.enable_talos~}
      Version: ${var.talos_version}
      Architecture: ${var.talos_architecture}
      Kernel URL: ${local.talos_boot_urls.kernel}
      Initrd URL: ${local.talos_boot_urls.initrd}
      Status: Ready for download
    %{else~}
      Status: Disabled
    %{endif~}
    
    Debian Linux:
    %{if var.enable_debian~}
      Version: ${var.debian_version}
      Architecture: ${var.debian_architecture}
      Kernel URL: ${local.debian_boot_urls.kernel}
      Initrd URL: ${local.debian_boot_urls.initrd}
      Status: Ready for download
    %{else~}
      Status: Disabled
    %{endif~}
    
    Note: Assets must be downloaded manually or via automated scripts
  EOT

  filename = "${var.pxe_root_path}/.download-status.txt"

  depends_on = [
    local_file.pxe_root_directory
  ]
}
