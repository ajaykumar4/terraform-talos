# terraform-talos

[![Terraform Validate](https://img.shields.io/badge/terraform-valid-brightgreen)](#)
[![Talos](https://img.shields.io/badge/talos-v1.12.4-blue)](https://www.talos.dev)
[![Kubernetes](https://img.shields.io/badge/kubernetes-v1.35.2-blue)](https://kubernetes.io)

Declarative Terraform project for a **Talos Linux** Kubernetes cluster with:

- 🔐 **Passbolt** — read cluster details from Passbolt; write generated secrets back
- 🗄️ **MinIO** — self-hosted S3-compatible remote state backend
- ♻️ Full lifecycle — **bootstrap**, **config apply**, **Talos upgrade**, **K8s upgrade**, **node reset** — all via `terraform apply`

---

## Project Structure

```
terraform-talos/
├── backend.tf               # MinIO S3 backend configuration
├── versions.tf              # Terraform tools block, providers
├── variables.tf             # All inputs: CP/worker nodes, versions, Passbolt, lifecycle flags
├── locals.tf                # Inlined patch YAML + per-node computed values
├── secrets.tf               # talos_machine_secrets — cluster CA & tokens
├── machine_config.tf        # Machine configs + apply to all nodes (for_each)
├── cluster.tf               # Bootstrap, kubeconfig, upgrade & reset operations
├── passbolt.tf              # Read endpoint from Passbolt; write secrets back
├── outputs.tf               # talosconfig, kubeconfig, Passbolt IDs
└── terraform.tfvars.example # Copy → terraform.tfvars and fill in values
```

### MinIO State Layout

```
myminio/
└── <cluster_name>/               ← one bucket per cluster (default: "kubernetes")
    └── terraform-state/
        └── terraform.tfstate
```

The MinIO backend is configured via CLI flags during `terraform init` to keep your credentials and bucket endpoints out of source control.

---

## ✅ Can I Bootstrap Now?

**Yes — with the following pre-checks complete:**

| # | Check | Verify with |
|---|---|---|
| 1 | Node is booted into Talos **maintenance mode** (ISO or factory image) | `talosctl --nodes 192.168.8.2 version --insecure` |
| 2 | Node is reachable from your machine on port `50000` (Talos API) | `nc -zv 192.168.8.2 50000` |
| 3 | MinIO bucket `kubernetes` exists | `mc ls myminio/kubernetes` |
| 4 | `terraform.tfvars` exists with real values | `cat terraform.tfvars` |
| 5 | Passbolt is reachable and GPG key exported | `curl -s $PASSBOLT_URL/healthcheck` |
| 6 | All env vars are set (see Step 2 below) | `env \| grep -E 'AWS_\|TF_VAR'` |

> [!WARNING]
> **Existing cluster?** If the node already has Talos installed, do **not** run a fresh apply — you must import the existing secrets first. See [Importing an Existing Cluster](#importing-an-existing-cluster) below.

---

## Prerequisites

### Tools

This project uses [mise](https://mise.jdx.dev/) to manage tool versions (`terraform`, `opentofu`, `talosctl`, `kubectl`, `helm`, `mc`).

```sh
# Install tools globally or for this project directory
mise install

# GnuPG must usually be installed via your system package manager
brew install gnupg   # macOS
```

### MinIO Bucket

The Terraform S3 backend requires the state bucket to exist before `terraform init` can run. Create it once in the MinIO console or CLI before proceeding:

```sh
# Using the MinIO console — create a bucket named after your cluster, e.g. "kubernetes"

# Or using mc (MinIO Client):
mc alias set myminio http://minio.local:9000 <access-key> <secret-key>
mc mb myminio/kubernetes
```

> [!NOTE]
> Bucket name must match the `cluster_name` variable (default: `kubernetes`). One bucket per cluster — multiple clusters share one MinIO instance without collisions.

### Passbolt GPG Key

Export your Passbolt GPG private key:

```sh
# List your keys
gpg --list-secret-keys --keyid-format LONG

# Export (replace KEY_ID with your actual key ID)
gpg --armor --export-secret-key KEY_ID > ~/.gnupg/passbolt_private.asc
chmod 600 ~/.gnupg/passbolt_private.asc
```

Before the first apply, create a password entry in Passbolt for the cluster endpoint:

| Entry name | `password` field | Purpose |
|---|---|---|
| `talos-cluster-endpoint` | `https://192.168.8.200:6443` | Endpoint read back by Terraform |

Copy the entry UUID from the Passbolt URL (`/app/passwords/view/<UUID>`) and set it as `passbolt_resource_id_cluster_endpoint` in your `terraform.tfvars`.

---

## Step-by-Step Bootstrap

### Step 1 — Boot the node

Boot from the Talos factory ISO or PXE image. The node enters **maintenance mode** automatically.

```sh
# Verify the node is in maintenance mode (no auth needed yet)
talosctl --nodes 192.168.8.2 version --insecure
```

Expected: output contains `Server:` with the Talos version.

### Step 2 — Set environment variables

Copy the example `.env` file and fill it with your credentials:

```sh
cp .env.example .env
```

Your `.env` file should look like this:

```sh
# MinIO — used by the Terraform S3 backend
export AWS_ACCESS_KEY_ID="your-minio-access-key"
export AWS_SECRET_ACCESS_KEY="your-minio-secret-key"

# Passbolt — GPG key and passphrase
export TF_VAR_passbolt_private_key="$(cat ~/.gnupg/passbolt_private.asc)"
export TF_VAR_passbolt_passphrase="your-gpg-passphrase"
```

> [!NOTE]
> The `.env` file is git-ignored so your credentials won't be committed. Because we are using `mise`, all variables inside `.env` will be automatically loaded into your shell when you enter the project directory. Alternatively, you can run `source .env` manually.

### Step 3 — Create your tfvars

```sh
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

| Variable | Description |
|---|---|
| `minio_endpoint` | MinIO endpoint (e.g. `http://minio.local:9000`), used by outputs |
| `passbolt_url` | Your Passbolt base URL |
| `passbolt_resource_id_cluster_endpoint` | UUID of the Passbolt entry holding the endpoint |
| `cluster_name` | Cluster name — **must exactly match the bucket passed to 'terraform init'** |
| `cluster_node_network` | Subnet mask applied to every node (e.g. `/24`) |
| `cluster_gateway` | Default gateway applied to every node |
| `cluster_vip` | Layer-2 VIP URL dynamically injected into the control-plane |
| `controlplane_nodes` | Map of CP nodes (`ip`, `mac`, `mtu`, `schematic_id`, `secureboot` etc.) |
| `worker_nodes` | Map of worker nodes — leave `{}` for single-node |

> [!NOTE]
> **Versions:** `talos_version` and `kubernetes_version` are omitted here intentionally. Their defaults are managed inside `variables.tf` so Renovate can automatically submit PRs to keep them updated.

### Step 4 — Initialise Terraform

Initialize your MinIO backend via CLI flags. **Make sure your bucket name exactly matches your `cluster_name`.**

```sh
terraform init \
  -backend-config="endpoints={s3=\"http://minio.local:9000\"}" \
  -backend-config="bucket=kubernetes"
```

Expected: `Terraform has been successfully initialized!`

### Step 5 — Plan

```sh
terraform plan
```

Expected resources on a fresh cluster:

```
+ talos_machine_secrets.this
+ data.talos_client_configuration.this
+ data.talos_machine_configuration.controlplane["home-lab"]
+ talos_machine_configuration_apply.controlplane["home-lab"]
+ talos_machine_bootstrap.this
+ talos_cluster_kubeconfig.this
+ passbolt_password.talosconfig
+ passbolt_password.kubeconfig
+ passbolt_password.machine_secrets
```

> [!IMPORTANT]
> The plan must show **no destructive changes** (`-/+` or `-`). If you see any, investigate before applying.

### Step 6 — Apply

```sh
terraform apply
```

This single command:
1. Generates machine secrets (cluster CA, etcd tokens, etc.)
2. Applies machine configuration to every node — nodes reboot into configured state
3. Bootstraps etcd on the first control-plane node
4. Fetches the kubeconfig
6. Stores talosconfig, kubeconfig, and machine secrets in Passbolt
7. Writes `talosconfig` and `kubeconfig` locally to `~/.talos/config` and `~/.kube/config`

Total time: **5–15 minutes** depending on hardware.

### Step 7 — Verify cluster

Because Terraform automatically wrote your credentials to `~/.talos/config` and `~/.kube/config`, you can immediately verify the cluster:

```sh
# Verify Talos health
talosctl health

# Verify Kubernetes nodes & pods
kubectl get nodes
kubectl get pods -A
```

---

## Lifecycle Operations

You do **not** need to edit `terraform.tfvars` to trigger lifecycle operations. Instead, pass the flags directly to `terraform apply` via the CLI. This is a one-shot execution, meaning you never have to remember to "revert" variables manually afterwards.

### Upgrade Talos OS or Kubernetes

When Renovate submits a PR bumping the default `talos_version` or `kubernetes_version` in `variables.tf`, you can safely apply the new config to trigger the upgrades natively:

```sh
# To upgrade Talos OS across all nodes:
terraform apply -var="upgrade-nodes=true"

# To upgrade Kubernetes:
terraform apply -var="upgrade-k8s=true"
```

Nodes are upgraded **sequentially** (control-planes first, then workers).

### Factory Reset Cluster ⚠️

> [!CAUTION]
> This **wipes all node disks** and reboots the entire cluster back into maintenance mode. It is permanent and cannot be undone.

```sh
# Wipe the entire cluster:
terraform apply -var="reset=true"
```

---

## Scaling the Cluster

### Adding Control-Plane Nodes (must stay odd: 1 → 3 → 5)

```hcl
# terraform.tfvars
controlplane_nodes = {
  "home-lab" = { ... }   # existing
  "cp-2" = {
    ip             = "192.168.8.11"
    install_disk   = "/dev/sda"
    interface_mac  = "aa:bb:cc:dd:ee:02"
    mtu            = 1500
    schematic_id   = "1e177..."
    secureboot     = false
    encrypt_disk   = false
    kernel_modules = []
  }
  "cp-3" = { ... }
}
```

```sh
terraform apply   # applies config to new nodes and joins etcd
```

### Adding Worker Nodes (0 → N)

```hcl
# terraform.tfvars
worker_nodes = {
  "worker-1" = {
    ip             = "192.168.8.20"
    install_disk   = "/dev/sda"
    interface_mac  = "aa:bb:cc:dd:ff:01"
    mtu            = 1500
    schematic_id   = "1e177..."
    secureboot     = false
    encrypt_disk   = false
    kernel_modules = []
  }
}
```

```sh
terraform apply
```

---

## Importing an Existing Cluster

If the cluster was previously provisioned and you have the SOPS-encrypted secrets:

```sh
# 1. Decrypt the secrets
sops -d talsecret.sops.yaml > /tmp/talsecret.yaml

# 2. Import the secrets resource into state
terraform import talos_machine_secrets.this _

# 3. Provide the decrypted YAML content as the machine_secrets attribute
#    (via terraform state manipulation or by referencing the decrypted file)

# 4. Clean up
rm /tmp/talsecret.yaml
```

> [!NOTE]
> Terraform will re-apply machine configuration on the next apply. This is safe — Talos accepts idempotent re-applies without rebooting (unless a reboot-triggering field changed).

---

## Passbolt Integration

| Passbolt Entry Name | Content | Behaviour |
|---|---|---|
| `kubernetes-talosconfig` | talosconfig YAML | Written once — `ignore_changes` prevents overwrite |
| `kubernetes-kubeconfig` | kubeconfig YAML | Written once — `ignore_changes` prevents overwrite |
| `kubernetes-machine-secrets` | Talos machine secrets | Written once — `ignore_changes = all` (never touches again) |

---

## Security Notes

> [!CAUTION]
> - **Never commit `terraform.tfvars`** — it is git-ignored.
> - **MinIO state is not encrypted at rest by default** — enable MinIO server-side encryption for production.
> - **Machine secrets** live in Terraform state in plaintext — restrict MinIO bucket access appropriately.
> - **Passbolt entries** using `ignore_changes = all` are write-once, protecting against accidental secret rotation on re-apply.
