# Terraform Talos GitOps Template

Terraform-first template for building a Talos Kubernetes cluster and bootstrapping GitOps.

This repository is organized so a user can clone it, fill in variables, add local secrets, run Terraform, and end up with:

- Talos control-plane and worker nodes configured for HA
- local Terraform state stored in `infrastructure/terraform/state/terraform.tfstate`
- a generated `gitops/` tree with SOPS-encrypted manifests using Age
- Argo CD installed and bootstrapped
- Argo CD running in anonymous mode with no password login

## Layout

```text
.
├── gitops/
│   └── apps/                  # GitOps app values and Kustomize config tracked in Git
├── infrastructure/
│   ├── secrets/               # Local-only Age, Cloudflare, and Git deploy key files
│   └── terraform/             # Terraform root module, child modules, tfvars, and local state
└── README.md
```

## What Terraform Owns

Terraform is responsible for:

- generating Talos machine secrets and configs
- applying Talos config to control-plane and worker nodes
- bootstrapping the Talos cluster
- fetching `kubeconfig` and `talosconfig`
- rendering the environment-specific GitOps files into `gitops/`
- encrypting generated GitOps secrets with SOPS and Age
- installing the core bootstrap charts: Cilium, CoreDNS, cert-manager, and Argo CD
- creating the initial Argo CD project and applications

After bootstrap, Argo CD owns the app/config resources under `gitops/apps/`.

## Old Template Mapping

The old template inputs now map to Terraform like this:

- `cluster.sample.yaml` -> `infrastructure/terraform/terraform.tfvars`
- `nodes.sample.yaml` -> `controlplane_nodes` and `worker_nodes` in `infrastructure/terraform/terraform.tfvars`

Common mappings:

- `cluster.name` -> `cluster_name`
- `cluster.endpoint` / VIP -> `cluster_api_addr`
- node subnet -> `node_cidr`
- internal/external gateway IPs -> `cluster_dns_gateway_addr`, `cluster_gateway_addr`, `cloudflare_gateway_addr`
- Cloudflare domain -> `cloudflare_domain`
- repository -> `repository_name`
- Talos controller nodes -> `controlplane_nodes`
- Talos worker nodes -> `worker_nodes`

## Prerequisites

Install tools with `mise` if you want the repo-managed toolchain:

```bash
mise install
```

Examples in this README use `terraform`. If you use the `.mise.toml` toolchain, you can replace `terraform` with `tofu`.

Prepare these local files:

- `infrastructure/secrets/age.key`
- `infrastructure/secrets/cloudflare-tunnel.json`
- `infrastructure/secrets/github-deploy.key` if the Git repository is private

The Age key should include both:

- `# public key: age1...`
- `AGE-SECRET-KEY-...`

## Clone-To-Use Flow

### 1. Copy the example variables

```bash
cd infrastructure/terraform
cp terraform.tfvars.example terraform.tfvars
```

Fill in:

- cluster network settings
- API VIP
- Cloudflare domain and token
- repository name
- control-plane and worker node maps

The example file is already shaped for an HA layout with 3 control-plane nodes and 2 workers.

### 2. Add local secrets

Put these files in `infrastructure/secrets/`:

- `age.key`
- `cloudflare-tunnel.json`
- `github-deploy.key` only for private repositories

### 3. Initialize Terraform

```bash
cd infrastructure/terraform
terraform init
```

State is written locally to:

```text
infrastructure/terraform/state/terraform.tfstate
```

That file is intentionally not ignored, so you can commit it if that matches your workflow.

### 4. Bootstrap Talos

Enable Talos bootstrap in `terraform.tfvars`:

```hcl
run_bootstrap_talos = true
run_bootstrap_apps  = false
run_reset           = false
```

Then apply:

```bash
terraform apply -var-file=terraform.tfvars
```

This writes:

- `infrastructure/secrets/talosconfig`
- `infrastructure/secrets/kubeconfig`

By default, the generated `kubeconfig` uses the first control-plane node IP as
its API server address for bootstrap work. This avoids depending on the VIP
during initial cluster bring-up.

### 5. Bootstrap GitOps

After the Talos cluster is healthy, switch app bootstrap on:

```hcl
run_bootstrap_talos = false
run_bootstrap_apps  = true
run_reset           = false
```

Then apply again:

```bash
terraform apply -var-file=terraform.tfvars
```

This step:

- renders the generated `.sops.yaml` and GitOps secret files
- encrypts GitOps manifests with your Age key
- installs Argo CD and bootstrap charts
- creates the initial Argo CD applications

## Argo CD Access

Argo CD is configured for:

- `server.insecure: true`
- anonymous access enabled
- default anonymous role set to admin
- admin password login disabled

That means the UI can be used without creating or managing an `argo_password`.

## API Endpoint Choice

Terraform bootstrap intentionally prefers a reachable control-plane node IP for
Kubernetes API access instead of assuming the VIP is usable during first boot.

If you want to override that behavior, set this in
`infrastructure/terraform/terraform.tfvars`:

```hcl
kubernetes_api_addr = "192.168.8.2"
```

Use a value that is reachable from the machine running Terraform. If you point
it at something other than the VIP, make sure the Kubernetes API certificate
covers that address.

## Repository Conventions

### `gitops/apps/`

This directory contains the GitOps application definitions and Kustomize config that Argo CD syncs.

- generic values stay in plain `values.yaml`
- environment-specific generated values go into `*.sops.yaml`
- Terraform regenerates the environment-specific files from `terraform.tfvars`

### `infrastructure/secrets/`

This directory is local-only. Do not commit real secret files from it.

### `infrastructure/terraform/`

This is the Terraform root. Run `terraform fmt`, `terraform validate`, `terraform plan`, and `terraform apply` from here.

## Day-2 Operations

Use the feature toggles in `terraform.tfvars`:

- `run_upgrade_k8s = true`
- `run_upgrade_nodes = true`
- `run_reset = true`

Only enable one operational toggle at a time.

If Terraform state says Talos bootstrap already happened but the cluster was reset, increment:

```hcl
bootstrap_generation = 1
```

Increase it again only when you need to force Talos bootstrap to run again.

## Validation Commands

Run these from `infrastructure/terraform`:

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars
```

## Troubleshooting

If `terraform plan` or `kubectl` fails with `x509: certificate signed by unknown authority`, your local `talosconfig` or `kubeconfig` in `infrastructure/secrets/` no longer matches the live cluster.

This usually means one of these happened outside the current Terraform state:

- Talos was reset and bootstrapped again
- cluster certificates were rotated
- the live cluster was rebuilt from a different machine secret set

In that case, reconcile the live cluster and Terraform state before continuing. The repo structure and Terraform config can still be valid even when the live access files are stale.

## Notes

- `gitops/argo` and `gitops/components` are intentionally removed. Terraform now bootstraps Argo directly.
- Generated GitOps secret files are not committed in the starter template. Terraform creates them from your variables and local secrets.
- Private repositories use an SSH deploy key. Public repositories use the GitHub HTTPS URL.
