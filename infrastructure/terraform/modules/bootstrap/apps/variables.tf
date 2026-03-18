# GitOps / GitHub
variable "repository_name" { type = string }
variable "repository_branch" { type = string }
variable "repository_visibility" { type = string }
variable "github_deploy_key" {
  type      = string
  sensitive = true
}
variable "gitops_dir" { type = string }
variable "gitops_repo_path" { type = string }

# Age / SOPS Secrets
variable "age_private_key" {
  type      = string
  sensitive = true
}
variable "kubeconfig_path" { type = string }
variable "kubeconfig_raw" {
  type      = string
  sensitive = true
  default   = null
}
variable "kubernetes_api_addr" { type = string }

variable "cilium_bgp_enabled" { type = bool }
variable "cluster_pod_cidr" { type = string }
variable "cilium_loadbalancer_mode" { type = string }
