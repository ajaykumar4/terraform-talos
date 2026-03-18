locals {
  repo_root         = abspath("${path.root}/../..")
  gitops_dir        = abspath(var.gitops_local_path)
  gitops_apps_dir   = "${local.gitops_dir}/apps"
  sops_config_file  = "${local.repo_root}/.sops.yaml"
  render_dir        = "${path.root}/.rendered/gitops-assets"
  domain_slug       = replace(var.cloudflare_domain, ".", "-")
  external_hostname = "external.${var.cloudflare_domain}"
  internal_hostname = "internal.${var.cloudflare_domain}"

  sops_config = yamlencode({
    creation_rules = [
      {
        path_regex         = "gitops/.*\\.sops\\.ya?ml"
        encrypted_regex    = "^(data|stringData)$"
        mac_only_encrypted = true
        age                = var.age_public_key
      }
    ]
    stores = {
      yaml = {
        indent = 2
      }
    }
  })

  cloudflare_tunnel_config = yamlencode({
    ingress = [
      {
        hostname = "*.${var.cloudflare_domain}"
        originRequest = {
          http2Origin      = true
          originServerName = local.external_hostname
        }
        service = "https://envoy-external.network.svc.cluster.local:443"
      },
      {
        service = "http_status:404"
      }
    ]
  })

  envoy_documents = join("\n---\n", [
    yamlencode({
      apiVersion = "gateway.envoyproxy.io/v1alpha1"
      kind       = "EnvoyProxy"
      metadata = {
        name = "envoy"
      }
      spec = {
        logging = {
          level = {
            default = "info"
          }
        }
        provider = {
          type = "Kubernetes"
          kubernetes = {
            envoyDeployment = {
              replicas = 2
              container = {
                imageRepository = "mirror.gcr.io/envoyproxy/envoy"
                resources = {
                  requests = {
                    cpu = "100m"
                  }
                  limits = {
                    memory = "1Gi"
                  }
                }
              }
            }
            envoyService = {
              externalTrafficPolicy = "Cluster"
            }
          }
        }
        shutdown = {
          drainTimeout = "180s"
        }
        telemetry = {
          metrics = {
            prometheus = {
              compression = {
                type = "Zstd"
              }
            }
          }
        }
      }
    }),
    yamlencode({
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "GatewayClass"
      metadata = {
        name = "envoy"
      }
      spec = {
        controllerName = "gateway.envoyproxy.io/gatewayclass-controller"
        parametersRef = {
          group     = "gateway.envoyproxy.io"
          kind      = "EnvoyProxy"
          name      = "envoy"
          namespace = "network"
        }
      }
    }),
    yamlencode({
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "Gateway"
      metadata = {
        name = "envoy-external"
        annotations = {
          "external-dns.alpha.kubernetes.io/target" = local.external_hostname
        }
      }
      spec = {
        gatewayClassName = "envoy"
        infrastructure = {
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = local.external_hostname
            "lbipam.cilium.io/ips"                      = var.cloudflare_gateway_addr
          }
        }
        listeners = [
          {
            name     = "http"
            protocol = "HTTP"
            port     = 80
            allowedRoutes = {
              namespaces = {
                from = "Same"
              }
            }
          },
          {
            name     = "https"
            protocol = "HTTPS"
            port     = 443
            allowedRoutes = {
              namespaces = {
                from = "All"
              }
            }
            tls = {
              certificateRefs = [
                {
                  kind = "Secret"
                  name = "${local.domain_slug}-production-tls"
                }
              ]
            }
          }
        ]
      }
    }),
    yamlencode({
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "Gateway"
      metadata = {
        name = "envoy-internal"
        annotations = {
          "external-dns.alpha.kubernetes.io/target" = local.internal_hostname
        }
      }
      spec = {
        gatewayClassName = "envoy"
        infrastructure = {
          annotations = {
            "external-dns.alpha.kubernetes.io/hostname" = local.internal_hostname
            "lbipam.cilium.io/ips"                      = var.cluster_gateway_addr
          }
        }
        listeners = [
          {
            name     = "http"
            protocol = "HTTP"
            port     = 80
            allowedRoutes = {
              namespaces = {
                from = "Same"
              }
            }
          },
          {
            name     = "https"
            protocol = "HTTPS"
            port     = 443
            allowedRoutes = {
              namespaces = {
                from = "All"
              }
            }
            tls = {
              certificateRefs = [
                {
                  kind = "Secret"
                  name = "${local.domain_slug}-production-tls"
                }
              ]
            }
          }
        ]
      }
    }),
    yamlencode({
      apiVersion = "gateway.envoyproxy.io/v1alpha1"
      kind       = "BackendTrafficPolicy"
      metadata = {
        name = "envoy"
      }
      spec = {
        compressor = [
          {
            type = "Zstd"
            zstd = {}
          },
          {
            type   = "Brotli"
            brotli = {}
          },
          {
            type = "Gzip"
            gzip = {}
          }
        ]
        retry = {
          numRetries = 2
          retryOn = {
            triggers = ["reset"]
          }
        }
        targetSelectors = [
          {
            group = "gateway.networking.k8s.io"
            kind  = "Gateway"
          }
        ]
        tcpKeepalive = {}
        timeout = {
          http = {
            requestTimeout = "0s"
          }
        }
      }
    }),
    yamlencode({
      apiVersion = "gateway.envoyproxy.io/v1alpha1"
      kind       = "ClientTrafficPolicy"
      metadata = {
        name = "envoy"
      }
      spec = {
        clientIPDetection = {
          xForwardedFor = {
            trustedCIDRs = [var.cluster_pod_cidr]
          }
        }
        http2 = {
          onInvalidMessage = "TerminateStream"
        }
        http3 = {}
        targetSelectors = [
          {
            group = "gateway.networking.k8s.io"
            kind  = "Gateway"
          }
        ]
        tcpKeepalive = {}
        tls = {
          minVersion    = "1.2"
          alpnProtocols = ["h2", "http/1.1"]
        }
      }
    })
  ])

  cilium_network_documents = concat(
    [
      yamlencode({
        apiVersion = "cilium.io/v2alpha1"
        kind       = "CiliumLoadBalancerIPPool"
        metadata = {
          name = "pool"
        }
        spec = {
          allowFirstLastIPs = "No"
          blocks = [
            {
              cidr = var.node_cidr
            }
          ]
        }
      }),
      yamlencode({
        apiVersion = "cilium.io/v2alpha1"
        kind       = "CiliumL2AnnouncementPolicy"
        metadata = {
          name = "l2-policy"
        }
        spec = {
          loadBalancerIPs = true
          nodeSelector = {
            matchLabels = {
              "kubernetes.io/os" = "linux"
            }
          }
        }
      })
    ],
    var.cilium_bgp_enabled ? [
      yamlencode({
        apiVersion = "cilium.io/v2alpha1"
        kind       = "CiliumBGPAdvertisement"
        metadata = {
          name = "bgp-advertisement-config"
          labels = {
            advertise = "bgp"
          }
        }
        spec = {
          advertisements = [
            {
              advertisementType = "Service"
              service = {
                addresses = ["LoadBalancerIP"]
              }
              selector = {
                matchExpressions = [
                  {
                    key      = "somekey"
                    operator = "NotIn"
                    values   = ["never-used-value"]
                  }
                ]
              }
            }
          ]
        }
      }),
      yamlencode({
        apiVersion = "cilium.io/v2alpha1"
        kind       = "CiliumBGPPeerConfig"
        metadata = {
          name = "bgp-peer-config-v4"
        }
        spec = {
          families = [
            {
              afi  = "ipv4"
              safi = "unicast"
              advertisements = {
                matchLabels = {
                  advertise = "bgp"
                }
              }
            }
          ]
        }
      }),
      yamlencode({
        apiVersion = "cilium.io/v2alpha1"
        kind       = "CiliumBGPClusterConfig"
        metadata = {
          name = "bgp-cluster-config"
        }
        spec = {
          nodeSelector = {
            matchLabels = {
              "kubernetes.io/os" = "linux"
            }
          }
          bgpInstances = [
            {
              name     = "instance-${var.cilium_bgp_node_asn}"
              localASN = tonumber(var.cilium_bgp_node_asn)
              peers = [
                {
                  name        = "peer-${var.cilium_bgp_router_asn}-v4"
                  peerASN     = tonumber(var.cilium_bgp_router_asn)
                  peerAddress = var.cilium_bgp_router_addr
                  peerConfigRef = {
                    name = "bgp-peer-config-v4"
                  }
                }
              ]
            }
          ]
        }
      })
    ] : []
  )

  plain_gitops_files = {
    (local.sops_config_file)                                           = local.sops_config
    "${local.gitops_apps_dir}/kube-system/cilium/config/networks.yaml" = join("\n---\n", local.cilium_network_documents)
  }

  sensitive_gitops_files = {
    "${local.gitops_apps_dir}/argo-system/argo-cd/config/http-route.sops.yaml" = yamlencode({
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "HTTPRoute"
      metadata = {
        name = "argo"
      }
      spec = {
        parentRefs = [
          {
            name        = "envoy-external"
            namespace   = "network"
            sectionName = "https"
          }
        ]
        hostnames = ["argo.${var.cloudflare_domain}"]
        rules = [
          {
            backendRefs = [
              {
                name = "argocd-server"
                port = 80
              }
            ]
          }
        ]
      }
    })
    "${local.gitops_apps_dir}/cert-manager/cert-manager/issuers/clusterissuers.sops.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "letsencrypt-production"
      }
      spec = {
        acme = {
          privateKeySecretRef = {
            name = "letsencrypt-production"
          }
          profile = "shortlived"
          server  = "https://acme-v02.api.letsencrypt.org/directory"
          solvers = [
            {
              dns01 = {
                cloudflare = {
                  apiTokenSecretRef = {
                    name = "cert-manager-secret"
                    key  = "api-token"
                  }
                }
              }
              selector = {
                dnsZones = [var.cloudflare_domain]
              }
            }
          ]
        }
      }
    })
    "${local.gitops_apps_dir}/cert-manager/cert-manager/issuers/secret.sops.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name = "cert-manager-secret"
      }
      stringData = {
        "api-token" = var.cloudflare_token
      }
    })
    "${local.gitops_apps_dir}/network/cloudflare-dns/values.sops.yaml" = yamlencode({
      fullnameOverride = "cloudflare-dns"
      provider         = "cloudflare"
      env = [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = "cloudflare-dns-secret"
              key  = "api-token"
            }
          }
        }
      ]
      extraArgs = [
        "--cloudflare-dns-records-per-page=1000",
        "--cloudflare-proxied",
        "--crd-source-apiversion=externaldns.k8s.io/v1alpha1",
        "--crd-source-kind=DNSEndpoint",
        "--gateway-name=envoy-external",
      ]
      triggerLoopOnEvent = true
      policy             = "sync"
      sources            = ["crd", "gateway-httproute"]
      txtPrefix          = "k8s."
      txtOwnerId         = "default"
      domainFilters      = [var.cloudflare_domain]
      serviceMonitor = {
        enabled = false
      }
      podAnnotations = {
        "secret.reloader.stakater.com/reload" = "cloudflare-dns-secret"
      }
    })
    "${local.gitops_apps_dir}/network/cloudflare-dns/config/secret.sops.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name = "cloudflare-dns-secret"
      }
      stringData = {
        "api-token" = var.cloudflare_token
      }
    })
    "${local.gitops_apps_dir}/network/cloudflare-tunnel/values.sops.yaml" = yamlencode({
      controllers = {
        "cloudflare-tunnel" = {
          strategy = "RollingUpdate"
          annotations = {
            "reloader.stakater.com/auto" = "true"
          }
          containers = {
            app = {
              image = {
                repository = "docker.io/cloudflare/cloudflared"
                tag        = "2026.3.0"
              }
              env = {
                NO_AUTOUPDATE             = true
                TUNNEL_METRICS            = "0.0.0.0:8080"
                TUNNEL_POST_QUANTUM       = true
                TUNNEL_TRANSPORT_PROTOCOL = "quic"
              }
              envFrom = [
                {
                  secretRef = {
                    name = "cloudflare-tunnel-secret"
                  }
                }
              ]
              args = ["tunnel", "run"]
              probes = {
                liveness = {
                  enabled = true
                  custom  = true
                  spec = {
                    httpGet = {
                      path = "/ready"
                      port = 8080
                    }
                    initialDelaySeconds = 0
                    periodSeconds       = 10
                    timeoutSeconds      = 1
                    failureThreshold    = 3
                  }
                }
                readiness = {
                  enabled = true
                  custom  = true
                  spec = {
                    httpGet = {
                      path = "/ready"
                      port = 8080
                    }
                    initialDelaySeconds = 0
                    periodSeconds       = 10
                    timeoutSeconds      = 1
                    failureThreshold    = 3
                  }
                }
              }
              securityContext = {
                allowPrivilegeEscalation = false
                readOnlyRootFilesystem   = true
                capabilities = {
                  drop = ["ALL"]
                }
              }
              resources = {
                requests = {
                  cpu = "10m"
                }
                limits = {
                  memory = "256Mi"
                }
              }
            }
          }
        }
      }
      defaultPodOptions = {
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 65534
          runAsGroup   = 65534
        }
      }
      service = {
        app = {
          ports = {
            http = {
              port = 8080
            }
          }
        }
      }
      serviceMonitor = {
        app = {
          enabled = false
        }
      }
      configMaps = {
        config = {
          data = {
            "config.yaml" = local.cloudflare_tunnel_config
          }
        }
      }
      persistence = {
        "config-file" = {
          type       = "configMap"
          identifier = "config"
          globalMounts = [
            {
              path    = "/etc/cloudflared/config.yaml"
              subPath = "config.yaml"
            }
          ]
        }
      }
    })
    "${local.gitops_apps_dir}/network/cloudflare-tunnel/config/secret.sops.yaml" = yamlencode({
      apiVersion = "v1"
      kind       = "Secret"
      metadata = {
        name = "cloudflare-tunnel-secret"
      }
      stringData = {
        TUNNEL_TOKEN = var.cloudflare_tunnel_token
      }
    })
    "${local.gitops_apps_dir}/network/cloudflare-tunnel/config/dnsendpoint.sops.yaml" = yamlencode({
      apiVersion = "externaldns.k8s.io/v1alpha1"
      kind       = "DNSEndpoint"
      metadata = {
        name = "cloudflare-tunnel"
      }
      spec = {
        endpoints = [
          {
            dnsName    = local.external_hostname
            recordType = "CNAME"
            targets    = ["${var.cloudflare_tunnel_id}.cfargotunnel.com"]
          }
        ]
      }
    })
    "${local.gitops_apps_dir}/network/envoy-gateway/config/certificate.sops.yaml" = yamlencode({
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name = "${local.domain_slug}-production"
      }
      spec = {
        dnsNames = [
          var.cloudflare_domain,
          "*.${var.cloudflare_domain}"
        ]
        duration = "160h"
        issuerRef = {
          name = "letsencrypt-production"
          kind = "ClusterIssuer"
        }
        privateKey = {
          algorithm = "ECDSA"
        }
        secretName = "${local.domain_slug}-production-tls"
        usages     = ["digital signature"]
      }
    })
    "${local.gitops_apps_dir}/network/envoy-gateway/config/envoy.sops.yaml" = local.envoy_documents
    "${local.gitops_apps_dir}/network/k8s-gateway/values.sops.yaml" = yamlencode({
      fullnameOverride = "k8s-gateway"
      domain           = var.cloudflare_domain
      ttl              = 1
      service = {
        type = "LoadBalancer"
        port = 53
        annotations = {
          "io.cilium/lb-ipam-ips" = var.cluster_dns_gateway_addr
        }
        externalTrafficPolicy = "Cluster"
      }
      watchedResources = ["HTTPRoute", "Service"]
    })
    "${local.gitops_apps_dir}/default/echo/values.sops.yaml" = yamlencode({
      route = {
        app = {
          hostnames = ["echo.${var.cloudflare_domain}"]
          parentRefs = [
            {
              name        = "envoy-external"
              namespace   = "network"
              sectionName = "https"
            }
          ]
          rules = [
            {
              backendRefs = [
                {
                  identifier = "app"
                  port       = 8080
                }
              ]
            }
          ]
        }
      }
    })
  }

  sensitive_render_files = {
    for target, content in local.sensitive_gitops_files :
    target => {
      plain_file    = "${local.render_dir}/${replace(trimprefix(target, "${local.repo_root}/"), "/", "__")}"
      relative_path = trimprefix(target, "${local.repo_root}/")
      content       = content
    }
  }
}

resource "local_file" "plain_gitops_file" {
  for_each = local.plain_gitops_files

  filename = each.key
  content  = each.value
}

resource "terraform_data" "render_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${local.render_dir}"
  }
}

resource "local_sensitive_file" "sensitive_render_file" {
  for_each   = local.sensitive_render_files
  depends_on = [terraform_data.render_dir]

  filename = each.value.plain_file
  content  = each.value.content
}

resource "terraform_data" "encrypt_sensitive_gitops_file" {
  for_each = local.sensitive_render_files

  triggers_replace = [
    sha256(each.value.content),
    var.age_public_key,
  ]

  depends_on = [
    local_file.plain_gitops_file,
    local_sensitive_file.sensitive_render_file,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p "${dirname(each.key)}"
      SOPS_CONFIG="${local.sops_config_file}" sops --encrypt \
        --filename-override "${each.value.relative_path}" \
        --input-type yaml \
        --output-type yaml \
        "${each.value.plain_file}" > "${each.key}"
    EOT
  }
}
