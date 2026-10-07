variable "matchbox_http_endpoint" {
  type    = string
  default = "http://192.168.8.100:8080"
}

variable "matchbox_rpc_endpoint" {
  type    = string
  default = "127.0.0.1:8081"
}

variable "matchbox_assets_path" {
  type        = string
  default     = "~/matchbox/assets"
  description = "Path to Matchbox assets directory on MacBook"
}

# Global OS & Secret Settings
variable "debian_version" {
  type    = string
  default = "bookworm"
}

variable "talos_version" {
  type    = string
  default = "v1.7.0"
}

variable "debian_root_password" {
  type      = string
  default   = "GlobalDefaultPassword123!"
  sensitive = true
}

# Unified Inventory
variable "nodes" {
  type = map(object({
    hostname = string
    arch     = string # "amd64" or "arm64"
    os       = string # "debian" or "talos"
    mac      = string
  }))
}