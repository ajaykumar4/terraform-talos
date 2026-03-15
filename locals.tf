##############################################################################
# locals.tf
# Patch YAML content (inlined from original talos/patches/) and computed
# per-node values used across machine_config.tf and cluster.tf.
##############################################################################

locals {

  ###########################################################################
  # Node aliases
  # Control-plane and worker nodes now come from separate variables, so
  # locals just alias them for consistency with the rest of the codebase.
  ###########################################################################

  controlplane_nodes = var.controlplane_nodes
  worker_nodes       = var.worker_nodes

  # All nodes combined — used to build per-node patches
  all_nodes = merge(var.controlplane_nodes, var.worker_nodes)

  # First control-plane IP (sorted for determinism) — bootstrap target
  first_controlplane_ip = sort(values(var.controlplane_nodes)[*].ip)[0]

  # Compute the API endpoint directly from the VIP
  cluster_endpoint = "https://${var.cluster_vip}:6443"

  ###########################################################################
  # GLOBAL PATCHES — applied to ALL nodes
  ###########################################################################

  # machine-files.yaml — containerd customisation
  patch_global_machine_files = <<-YAML
    machine:
      files:
        - op: create
          path: /etc/cri/conf.d/20-customization.part
          content: |
            [plugins."io.containerd.cri.v1.images"]
              discard_unpacked_layers = false
            [plugins."io.containerd.cri.v1.runtime"]
              device_ownership_from_security_context = true
  YAML

  # machine-kubelet.yaml — kubelet tuning
  patch_global_machine_kubelet = <<-YAML
    machine:
      kubelet:
        extraConfig:
          serializeImagePulls: false
        nodeIP:
          validSubnets:
            - 192.168.8.0/24
  YAML

  # machine-network.yaml — DNS / search domain
  patch_global_machine_network = yamlencode({
    machine = {
      network = {
        disableSearchDomain = true
        nameservers         = var.cluster_dns_servers
      }
    }
  })

  # machine-sysctls.yaml — kernel tuning for inotify, QUIC, ARP, namespaces
  patch_global_machine_sysctls = <<-YAML
    machine:
      sysctls:
        fs.inotify.max_user_watches: "1048576"
        fs.inotify.max_user_instances: "8192"
        net.core.rmem_max: "7500000"
        net.core.wmem_max: "7500000"
        net.ipv4.neigh.default.gc_thresh1: "4096"
        net.ipv4.neigh.default.gc_thresh2: "8192"
        net.ipv4.neigh.default.gc_thresh3: "16384"
        net.ipv4.tcp_slow_start_after_idle: "0"
        user.max_user_namespaces: "11255"
  YAML

  # machine-time.yaml — NTP
  patch_global_machine_time = yamlencode({
    machine = {
      time = {
        disabled = false
        servers  = var.cluster_ntp_servers
      }
    }
  })

  # All global patches ordered to match talconfig.yaml patches[]
  patches_global = [
    local.patch_global_machine_files,
    local.patch_global_machine_kubelet,
    local.patch_global_machine_network,
    local.patch_global_machine_sysctls,
    local.patch_global_machine_time,
  ]

  ###########################################################################
  # CONTROLLER PATCHES — control-plane nodes only
  #
  # allowSchedulingOnControlPlanes=true lets workloads run on CPs when
  # worker_nodes is empty (valid for single-node or small-cluster setups).
  ###########################################################################

  patch_controller_cluster = <<-YAML
    cluster:
      allowSchedulingOnControlPlanes: true
      apiServer:
        admissionControl: []
        extraArgs:
          enable-aggregator-routing: "true"
      controllerManager:
        extraArgs:
          bind-address: 0.0.0.0
      coreDNS:
        disabled: true
      etcd:
        extraArgs:
          listen-metrics-urls: http://0.0.0.0:2381
        advertisedSubnets:
          - 192.168.8.0/24
      proxy:
        disabled: true
      scheduler:
        extraArgs:
          bind-address: 0.0.0.0
  YAML

  patch_controller_cert_sans = yamlencode({
    machine = {
      certSANs = concat(["127.0.0.1", var.cluster_vip], var.cluster_api_tls_sans)
    }
  })

  patches_controlplane = concat(local.patches_global, [
    local.patch_controller_cluster,
    local.patch_controller_cert_sans,
  ])

  ###########################################################################
  # Per-node network + install patches
  # Built from all_nodes so both CP and worker nodes are covered in one pass.
  ###########################################################################

  patches_per_node = {
    for hostname, node in local.all_nodes : hostname => [
      yamlencode({
        machine = {
          network = {
            interfaces = [
              merge(
                {
                  deviceSelector = {
                    hardwareAddr = node.interface_mac
                  }
                  dhcp      = false
                  addresses = ["${node.ip}${var.cluster_node_network}"]
                  mtu       = node.mtu
                  routes = [
                    {
                      network = "0.0.0.0/0"
                      gateway = var.cluster_gateway
                    }
                  ]
                },
                # Control planes get the VIP mapping; workers do not.
                contains(keys(local.controlplane_nodes), hostname) ? { vip = { ip = var.cluster_vip } } : {}
              )
            ]
          }
          install = merge(
            {
              disk  = node.install_disk
              image = "${node.schematic_id != "" ? "factory.talos.dev/installer/${node.schematic_id}" : "ghcr.io/siderolabs/installer"}:${var.talos_version}"
              wipe  = false
            },
            # SecureBoot — only emitted when enabled
            node.secureboot ? { secureboot = true } : {},
            # Disk encryption via TPM — only emitted when enabled
            node.encrypt_disk ? {
              diskEncryption = {
                state = {
                  provider = "luks2"
                  options  = [{ name = "no_read_workqueue" }, { name = "no_write_workqueue" }]
                  keys     = [{ nodeID = {}, slot = 0 }]
                }
                ephemeral = {
                  provider = "luks2"
                  options  = [{ name = "no_read_workqueue" }, { name = "no_write_workqueue" }]
                  keys     = [{ nodeID = {}, slot = 0 }]
                }
              }
            } : {},
          )
          # Kernel modules — only emitted when list is non-empty
          kernel = length(node.kernel_modules) > 0 ? {
            modules = [for m in node.kernel_modules : { name = m }]
          } : null
        }
      })
    ]
  }
}
