variable "hostname" {
  type        = string
  description = "Node hostname / identifier"
}

variable "mac" {
  type        = string
  description = "Network interface MAC address"
}

variable "os_type" {
  type        = string
  description = "'debian' or 'talos'"

  validation {
    condition     = contains(["debian", "talos"], var.os_type)
    error_message = "os_type must be either 'debian' or 'talos'."
  }
}

variable "arch" {
  type        = string
  default     = "amd64"
  description = "'amd64' or 'arm64'"

  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "arch must be either 'amd64' or 'arm64'."
  }
}

variable "debian_version" {
  type        = string
  description = "Global Debian version (e.g. bookworm)"
}

variable "talos_version" {
  type        = string
  description = "Global Talos version (e.g. v1.7.0)"
}

variable "debian_root_password" {
  type        = string
  sensitive   = true
  description = "Global Debian root password"
}

variable "matchbox_http_endpoint" {
  type        = string
  description = "Base HTTP URL for Matchbox"
}

variable "matchbox_assets_path" {
  type        = string
  default     = "~/matchbox/assets"
  description = "Local path for Matchbox assets directory"
}