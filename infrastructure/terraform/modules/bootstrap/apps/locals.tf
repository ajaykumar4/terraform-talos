locals {
  gitops_apps_dir       = "${var.gitops_dir}/apps"
  repository_https_url  = "https://github.com/${var.repository_name}.git"
  repository_ssh_url    = "git@github.com:${var.repository_name}.git"
  repository_source_url = var.repository_visibility == "private" ? local.repository_ssh_url : local.repository_https_url
  kubeconfig_content    = try(yamldecode(var.kubeconfig_raw), yamldecode(file(var.kubeconfig_path)))
  bootstrap_kubeconfig = yamlencode(merge(local.kubeconfig_content, {
    clusters = [
      for cluster in local.kubeconfig_content.clusters :
      merge(cluster, {
        cluster = merge(cluster.cluster, {
          server = "https://${var.kubernetes_api_addr}:6443"
        })
      })
    ]
  }))
  bootstrap_kubeconfig_path = "${path.root}/.bootstrap-kubeconfig"

  namespaces = toset([
    "argo-system",
    "cert-manager",
    "network",
  ])

  repository_secret_data = merge(
    {
      type = "git"
      url  = var.repository_visibility == "private" ? local.repository_ssh_url : local.repository_https_url
    },
    var.repository_visibility == "private" ? { sshPrivateKey = var.github_deploy_key } : {}
  )

  helm_secrets_manifest = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "helm-secrets-private-keys"
      namespace = "argo-system"
    }
    type = "Opaque"
    stringData = {
      "key.txt" = var.age_private_key
    }
  })

  repository_secret_manifest = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "github"
      namespace = "argo-system"
      labels = {
        "argocd.argoproj.io/secret-type" = "repository"
      }
      annotations = {
        "argocd.argoproj.io/sync-wave" = "1"
      }
    }
    type       = "Opaque"
    stringData = local.repository_secret_data
  })

  argocd_sync_policy = {
    automated = {
      allowEmpty = true
      prune      = true
      selfHeal   = true
    }
    retry = {
      limit = 1
      backoff = {
        duration    = "10s"
        factor      = 2
        maxDuration = "3m"
      }
    }
    syncOptions = [
      "CreateNamespace=true",
      "ApplyOutOfSyncOnly=true",
      "ServerSideApply=true",
      "PruneLast=true",
      "RespectIgnoreDifferences=true",
    ]
  }

  cilium_helm_values = [
    yamlencode(merge(
      {
        autoDirectNodeRoutes = true
        bpf = {
          masquerade        = true
          hostLegacyRouting = true
        }
        cni = {
          exclusive = false
        }
        cgroup = {
          automount = {
            enabled = false
          }
          hostRoot = "/sys/fs/cgroup"
        }
        dashboards = {
          enabled = true
        }
        endpointRoutes = {
          enabled = true
        }
        envoy = {
          enabled = false
        }
        gatewayAPI = {
          enabled = false
        }
        hubble = {
          enabled = false
        }
        ipam = {
          mode = "kubernetes"
        }
        ipv4NativeRoutingCIDR               = var.cluster_pod_cidr
        k8sServiceHost                      = "127.0.0.1"
        k8sServicePort                      = 7445
        kubeProxyReplacement                = true
        kubeProxyReplacementHealthzBindAddr = "0.0.0.0:10256"
        l2announcements = {
          enabled = true
        }
        loadBalancer = {
          algorithm = "maglev"
          mode      = var.cilium_loadbalancer_mode
        }
        localRedirectPolicies = {
          enabled = true
        }
        operator = {
          dashboards = {
            enabled = true
          }
          prometheus = {
            enabled = true
            serviceMonitor = {
              enabled = false
            }
          }
          replicas    = 1
          rollOutPods = true
        }
        prometheus = {
          enabled = true
          serviceMonitor = {
            enabled        = false
            trustCRDsExist = true
          }
        }
        rollOutCiliumPods = true
        routingMode       = "native"
        securityContext = {
          capabilities = {
            ciliumAgent = [
              "CHOWN",
              "KILL",
              "NET_ADMIN",
              "NET_RAW",
              "IPC_LOCK",
              "SYS_ADMIN",
              "SYS_RESOURCE",
              "PERFMON",
              "BPF",
              "DAC_OVERRIDE",
              "FOWNER",
              "SETGID",
              "SETUID",
            ]
            cleanCiliumState = [
              "NET_ADMIN",
              "SYS_ADMIN",
              "SYS_RESOURCE",
            ]
          }
        }
        socketLB = {
          enabled           = true
          hostNamespaceOnly = true
        }
      },
      var.cilium_bgp_enabled ? {
        bgpControlPlane = {
          enabled = true
        }
      } : {}
    ))
  ]
  cilium_helm_values_content       = join("\n---\n", local.cilium_helm_values)
  coredns_helm_values_content      = file("${local.gitops_apps_dir}/kube-system/coredns/values.yaml")
  cert_manager_helm_values_content = file("${local.gitops_apps_dir}/cert-manager/cert-manager/values.yaml")

  argocd_helm_values = [
    file("${local.gitops_apps_dir}/argo-system/argo-cd/values.yaml")
  ]
  argocd_helm_values_content = join("\n---\n", local.argocd_helm_values)

  argocd_project_manifest = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "kubernetes"
      namespace = "argo-system"
      annotations = {
        "argocd.argoproj.io/sync-wave" = "0"
      }
    }
    spec = {
      destinations = [
        {
          name      = "*"
          namespace = "*"
          server    = "*"
        }
      ]
      sourceRepos = ["*"]
      clusterResourceWhitelist = [
        {
          group = "*"
          kind  = "*"
        }
      ]
    }
  })

  argocd_application_manifests = {
    "argo-config" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "argo-config"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        source = {
          repoURL        = local.repository_source_url
          path           = "${var.gitops_repo_path}/apps/argo-system/argo-cd"
          targetRevision = var.repository_branch
        }
        destination = {
          name      = "in-cluster"
          namespace = "argo-system"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "cert-manager-issuers" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "cert-manager-issuers"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        source = {
          repoURL        = local.repository_source_url
          path           = "${var.gitops_repo_path}/apps/cert-manager/cert-manager"
          targetRevision = var.repository_branch
        }
        destination = {
          name      = "in-cluster"
          namespace = "cert-manager"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "cilium-config" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "cilium-config"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        source = {
          repoURL        = local.repository_source_url
          path           = "${var.gitops_repo_path}/apps/kube-system/cilium"
          targetRevision = var.repository_branch
        }
        destination = {
          name      = "in-cluster"
          namespace = "kube-system"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "metrics-server" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "metrics-server"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "https://kubernetes-sigs.github.io/metrics-server"
            chart          = "metrics-server"
            targetRevision = "3.13.0"
            helm = {
              releaseName = "metrics-server"
              valueFiles  = ["$repo/${var.gitops_repo_path}/apps/kube-system/metrics-server/values.yaml"]
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "kube-system"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "reloader" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "reloader"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "ghcr.io/stakater/charts"
            chart          = "reloader"
            targetRevision = "2.2.9"
            helm = {
              releaseName = "reloader"
              valueFiles  = ["$repo/${var.gitops_repo_path}/apps/kube-system/reloader/values.yaml"]
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "kube-system"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "cloudflare-dns" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "cloudflare-dns"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            path           = "${var.gitops_repo_path}/apps/network/cloudflare-dns"
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "https://kubernetes-sigs.github.io/external-dns"
            chart          = "external-dns"
            targetRevision = "1.20.0"
            helm = {
              releaseName = "cloudflare-dns"
              valueFiles  = ["$repo/${var.gitops_repo_path}/apps/network/cloudflare-dns/values.sops.yaml"]
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "network"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "cloudflare-tunnel" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "cloudflare-tunnel"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            path           = "${var.gitops_repo_path}/apps/network/cloudflare-tunnel"
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "ghcr.io/bjw-s-labs/helm"
            chart          = "app-template"
            targetRevision = "4.6.2"
            helm = {
              releaseName = "cloudflare-tunnel"
              valueFiles  = ["$repo/${var.gitops_repo_path}/apps/network/cloudflare-tunnel/values.sops.yaml"]
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "network"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "envoy-gateway" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "envoy-gateway"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            path           = "${var.gitops_repo_path}/apps/network/envoy-gateway"
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "mirror.gcr.io/envoyproxy"
            chart          = "gateway-helm"
            targetRevision = "v1.7.0"
            helm = {
              releaseName = "envoy-gateway"
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "network"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "k8s-gateway" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "k8s-gateway"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "https://ori-edge.github.io/k8s_gateway"
            chart          = "k8s-gateway"
            targetRevision = "2.4.0"
            helm = {
              releaseName = "k8s-gateway"
              valueFiles  = ["$repo/${var.gitops_repo_path}/apps/network/k8s-gateway/values.sops.yaml"]
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "network"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
    "echo" = yamlencode({
      apiVersion = "argoproj.io/v1alpha1"
      kind       = "Application"
      metadata = {
        name      = "echo"
        namespace = "argo-system"
        annotations = {
          "argocd.argoproj.io/sync-wave" = "0"
        }
      }
      spec = {
        project = "kubernetes"
        sources = [
          {
            repoURL        = local.repository_source_url
            targetRevision = var.repository_branch
            ref            = "repo"
          },
          {
            repoURL        = "ghcr.io/bjw-s-labs/helm"
            chart          = "app-template"
            targetRevision = "4.6.2"
            helm = {
              releaseName = "echo"
              valueFiles = [
                "$repo/${var.gitops_repo_path}/apps/default/echo/values.yaml",
                "$repo/${var.gitops_repo_path}/apps/default/echo/values.sops.yaml",
              ]
            }
          }
        ]
        destination = {
          name      = "in-cluster"
          namespace = "default"
        }
        syncPolicy = local.argocd_sync_policy
      }
    })
  }
}
