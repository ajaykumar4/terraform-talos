locals {
  # ----------------------------------------------------------------------------
  # NODE AGGREGATION & IMAGE CALCULATION
  # ----------------------------------------------------------------------------
  all_nodes = merge(var.controlplane_nodes, var.worker_nodes)

  node_images = {
    for k, v in local.all_nodes :
    k => v.schematic_id != "" ? "factory.talos.dev/installer${v.secureboot ? "-secureboot" : ""}/${v.schematic_id}:${var.talos_version}" : "ghcr.io/siderolabs/installer:${var.talos_version}"
  }

  # ----------------------------------------------------------------------------
  # GLOBAL PATCHES (Applied to ALL nodes)
  # ----------------------------------------------------------------------------
  patch_network = yamlencode({
    machine = {
      network = {
        disableSearchDomain = true
        nameservers         = var.node_dns_servers
      }
    }
  })

  patch_time = yamlencode({
    machine = { time = { servers = var.node_ntp_servers } }
  })

  patch_kubelet = yamlencode({
    machine = {
      kubelet = {
        extraConfig = { serializeImagePulls = false }
        nodeIP      = { validSubnets = [var.node_cidr] }
      }
    }
  })

  patch_sysctls = yamlencode({
    machine = {
      sysctls = {
        "fs.inotify.max_user_watches"        = "1048576"
        "fs.inotify.max_user_instances"      = "8192"
        "net.core.rmem_max"                  = "7500000"
        "net.core.wmem_max"                  = "7500000"
        "net.ipv4.neigh.default.gc_thresh1"  = "4096"
        "net.ipv4.neigh.default.gc_thresh2"  = "8192"
        "net.ipv4.neigh.default.gc_thresh3"  = "16384"
        "net.ipv4.tcp_slow_start_after_idle" = "0"
        "user.max_user_namespaces"           = "11255"
      }
    }
  })

  patch_containerd = yamlencode({
    machine = {
      files = [{
        op      = "create"
        path    = "/etc/cri/conf.d/20-customization.part"
        content = "[plugins.\"io.containerd.cri.v1.images\"]\n  discard_unpacked_layers = false\n[plugins.\"io.containerd.cri.v1.runtime\"]\n  device_ownership_from_security_context = true\n"
      }]
    }
  })

  # ============================================================================
  # CONTROLLER PATCHES (Applied ONLY to Control Plane nodes)
  # ============================================================================
  patch_cluster = yamlencode({
    cluster = {
      allowSchedulingOnControlPlanes = true
      apiServer = {
        # This is the magic for the $patch: delete syntax
        admissionControl = []
        extraArgs = {
          "enable-aggregator-routing" = "true"
        }
        certSANs = concat(["127.0.0.1", var.cluster_api_addr], var.cluster_api_tls_sans)
      }
      controllerManager = {
        extraArgs = { "bind-address" = "0.0.0.0" }
      }
      coreDNS = { disabled = true }
      proxy   = { disabled = true }
      network = {
        cni            = { name = "none" }
        podSubnets     = [var.cluster_pod_cidr]
        serviceSubnets = [var.cluster_svc_cidr]
      }
      scheduler = {
        extraArgs = { "bind-address" = "0.0.0.0" }
      }
      etcd = {
        advertisedSubnets = [var.node_cidr]
        extraArgs         = { "listen-metrics-urls" = "http://0.0.0.0:2381" }
      }
    }
    machine = {
      certSANs = concat(["127.0.0.1", var.cluster_api_addr], var.cluster_api_tls_sans)
    }
  })

  # ----------------------------------------------------------------------------
  # EXPORT LISTS
  # ----------------------------------------------------------------------------
  common_machine_patches = [
    local.patch_network,
    local.patch_time,
    local.patch_kubelet,
    local.patch_sysctls,
    local.patch_containerd
  ]

  controller_patches = [
    local.patch_cluster
  ]
}
