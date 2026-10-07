# Create boot profiles for each node
resource "matchbox_profile" "nodes" {
  for_each = local.nodes_config

  name   = "${each.value.hostname}-${each.value.os_type}-${each.value.arch}"
  kernel = each.value.kernel_path
  initrd = [each.value.initrd_path]
  args   = each.value.kernel_args

  depends_on = [local_file.debian_preseed]
}