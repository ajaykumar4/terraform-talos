resource "terraform_data" "kubernetes_api_ready" {
  depends_on = [local_sensitive_file.bootstrap_kubeconfig]

  triggers_replace = [
    sha256(local.bootstrap_kubeconfig),
    var.kubernetes_api_addr,
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      for attempt in {1..60}; do
        if kubectl --request-timeout=5s version >/dev/null 2>&1; then
          exit 0
        fi

        sleep 5
      done

      echo "Kubernetes API at https://${var.kubernetes_api_addr}:6443 did not become ready within 300 seconds." >&2
      exit 1
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "dynamic_namespaces" {
  for_each   = local.namespaces
  depends_on = [terraform_data.kubernetes_api_ready]

  triggers_replace = [each.key]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl create namespace ${each.key} --dry-run=client -o yaml | kubectl apply -f -"

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "local_sensitive_file" "bootstrap_kubeconfig" {
  content  = local.bootstrap_kubeconfig
  filename = local.bootstrap_kubeconfig_path
}

resource "terraform_data" "helm_secrets" {
  count      = var.age_private_key != "" ? 1 : 0
  depends_on = [terraform_data.dynamic_namespaces]

  triggers_replace = [sha256(local.helm_secrets_manifest)]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'EOF' | kubectl apply -f -
${local.helm_secrets_manifest}
EOF
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "repository" {
  depends_on = [terraform_data.dynamic_namespaces]

  triggers_replace = [sha256(local.repository_secret_manifest)]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'EOF' | kubectl apply -f -
${local.repository_secret_manifest}
EOF
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "cilium" {
  depends_on = [terraform_data.dynamic_namespaces]

  triggers_replace = [
    "1.19.1",
    sha256(local.cilium_helm_values_content),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      values_file="$(mktemp)"
      trap 'rm -f "$values_file"' EXIT

      cat <<'EOF' > "$values_file"
${local.cilium_helm_values_content}
EOF

      helm upgrade --install cilium oci://quay.io/cilium/charts/cilium \
        --version 1.19.1 \
        --namespace kube-system \
        --wait \
        --timeout 10m0s \
        -f "$values_file"
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "coredns" {
  depends_on = [terraform_data.cilium]

  triggers_replace = [
    "1.45.2",
    sha256(local.coredns_helm_values_content),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      values_file="$(mktemp)"
      trap 'rm -f "$values_file"' EXIT

      cat <<'EOF' > "$values_file"
${local.coredns_helm_values_content}
EOF

      helm upgrade --install coredns oci://ghcr.io/coredns/charts/coredns \
        --version 1.45.2 \
        --namespace kube-system \
        --wait \
        --timeout 10m0s \
        -f "$values_file"
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "cert_manager" {
  depends_on = [terraform_data.coredns]

  triggers_replace = [
    "v1.20.0",
    sha256(local.cert_manager_helm_values_content),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      values_file="$(mktemp)"
      trap 'rm -f "$values_file"' EXIT

      cat <<'EOF' > "$values_file"
${local.cert_manager_helm_values_content}
EOF

      helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
        --version v1.20.0 \
        --namespace cert-manager \
        --wait \
        --timeout 10m0s \
        -f "$values_file"
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "argocd" {
  depends_on = [terraform_data.cert_manager, terraform_data.helm_secrets, terraform_data.repository]

  triggers_replace = [
    "9.4.10",
    sha256(local.argocd_helm_values_content),
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      values_file="$(mktemp)"
      trap 'rm -f "$values_file"' EXIT

      cat <<'EOF' > "$values_file"
${local.argocd_helm_values_content}
EOF

      helm upgrade --install argocd oci://ghcr.io/argoproj/argo-helm/argo-cd \
        --version 9.4.10 \
        --namespace argo-system \
        --wait \
        --timeout 10m0s \
        -f "$values_file"
    EOT

    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "argocd_crds" {
  depends_on = [terraform_data.argocd, local_sensitive_file.bootstrap_kubeconfig]

  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Established --timeout=180s crd/applications.argoproj.io crd/appprojects.argoproj.io"
    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

removed {
  from = kubernetes_namespace.dynamic_namespaces

  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret.helm_secrets

  lifecycle {
    destroy = false
  }
}

removed {
  from = kubernetes_secret.repository

  lifecycle {
    destroy = false
  }
}

removed {
  from = helm_release.cilium

  lifecycle {
    destroy = false
  }
}

removed {
  from = helm_release.coredns

  lifecycle {
    destroy = false
  }
}

removed {
  from = helm_release.cert_manager

  lifecycle {
    destroy = false
  }
}

removed {
  from = helm_release.argocd

  lifecycle {
    destroy = false
  }
}

resource "terraform_data" "argocd_project" {
  depends_on = [terraform_data.argocd_crds]

  triggers_replace = [sha256(local.argocd_project_manifest)]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'EOF' | kubectl apply -f -
${local.argocd_project_manifest}
EOF
    EOT
    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}

resource "terraform_data" "argocd_application" {
  for_each = local.argocd_application_manifests

  depends_on = [terraform_data.argocd_project]

  triggers_replace = [sha256(each.value)]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      cat <<'EOF' | kubectl apply -f -
${each.value}
EOF
    EOT
    environment = {
      KUBECONFIG = local.bootstrap_kubeconfig_path
    }
  }
}
