# ------------------------------------------------------------------------------
# 1. Generate Configurations for All Nodes (CP & Workers)
# ------------------------------------------------------------------------------
data "talos_machine_configuration" "node" {
  for_each           = local.all_nodes
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${var.cluster_api_addr}:6443"
  machine_type       = each.value.is_cp ? "controlplane" : "worker"
  machine_secrets    = var.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = concat(
    [
      yamlencode({
        machine = {
          network = {
            interfaces = [
              merge(
                {
                  deviceSelector = { hardwareAddr = each.value.interface_mac }
                  mtu            = each.value.mtu
                },
                jsondecode(
                  var.node_vlan_tag != "" ?
                  jsonencode({
                    dhcp = false
                    vlans = [
                      merge(
                        {
                          vlanId    = tonumber(var.node_vlan_tag)
                          addresses = ["${each.value.ip}/${local.node_prefix_length}"]
                          routes    = [{ network = "0.0.0.0/0", gateway = var.node_default_gateway }]
                        },
                        each.value.is_cp ? { vip = { ip = var.cluster_api_addr } } : {}
                      )
                    ]
                  }) :
                  jsonencode(
                    merge(
                      {
                        dhcp      = false
                        addresses = ["${each.value.ip}/${local.node_prefix_length}"]
                        routes    = [{ network = "0.0.0.0/0", gateway = var.node_default_gateway }]
                      },
                      each.value.is_cp ? { vip = { ip = var.cluster_api_addr } } : {}
                    )
                  )
                )
              )
            ]
          }
          install = {
            disk  = each.value.install_disk
            image = var.node_images[each.key]
          }
        }
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        hostname   = each.key
        auto       = "off"
      })
    ],

    # Inject Global Patches (All Nodes)
    var.common_machine_patches,

    # Inject Controller Patches (Only for Control Planes)
    each.value.is_cp ? var.controller_patches : [],

    # Inject Disk Encryption (If enabled)
    each.value.encrypt_disk ? [yamlencode({
      machine = {
        systemDiskEncryption = {
          state     = { provider = "luks2", keys = [{ slot = 0, tpm = {} }] }
          ephemeral = { provider = "luks2", keys = [{ slot = 0, tpm = {} }] }
        }
      }
    })] : [],

    # Inject Kernel Modules (If defined)
    length(each.value.kernel_modules) > 0 ? [yamlencode({
      machine = { kernel = { modules = [for m in each.value.kernel_modules : { name = m }] } }
    })] : []
  )
}

# ------------------------------------------------------------------------------
# 2. Apply Configurations
# (If node exists, it patches the diff safely. If fresh, it provisions).
# ------------------------------------------------------------------------------
resource "talos_machine_configuration_apply" "node" {
  for_each                    = local.all_nodes
  client_configuration        = var.client_configuration
  machine_configuration_input = data.talos_machine_configuration.node[each.key].machine_configuration
  node                        = each.value.ip
  endpoint                    = each.value.ip
}

# ------------------------------------------------------------------------------
# 3. Bootstrap etcd
# ------------------------------------------------------------------------------
resource "terraform_data" "bootstrap_generation" {
  input = var.bootstrap_generation
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.node]
  client_configuration = var.client_configuration
  node                 = local.first_controlplane_ip
  endpoint             = local.first_controlplane_ip

  lifecycle {
    replace_triggered_by = [terraform_data.bootstrap_generation]
  }
}

# ------------------------------------------------------------------------------
# 4. Fetch Kubeconfig & Save Locally
# ------------------------------------------------------------------------------
resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = var.client_configuration
  node                 = local.first_controlplane_ip
  endpoint             = local.first_controlplane_ip
}

resource "local_sensitive_file" "kubeconfig" {
  content  = local.bootstrap_kubeconfig
  filename = "${path.root}/../secrets/kubeconfig"

  # Safety: Don't let a "tofu destroy" delete your only access to the cluster
  lifecycle {
    prevent_destroy = false # Set to true if you want extra safety
  }
}
