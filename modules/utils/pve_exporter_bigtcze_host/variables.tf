variable "ssh_host" {
  description = "SSH host address"
  type        = string
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "SSH port must be between 1 and 65535"
  }
}

variable "ssh_user" {
  description = "SSH user"
  type        = string
  default     = "root"
}

variable "ssh_password" {
  description = "SSH password (use ssh_private_key_path if available)"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key" {
  description = "SSH private key content"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
  default     = null
}

variable "listen_address" {
  description = "Listen address for the exporter"
  type        = string
  default     = "0.0.0.0"

  validation {
    condition     = can(regex("^[0-9A-Za-z._:-]+$", var.listen_address))
    error_message = "Listen address contains unsupported characters"
  }
}

variable "listen_port" {
  description = "Listen port for the exporter (bigtcze pve-exporter)"
  type        = number
  default     = 9222

  validation {
    condition     = var.listen_port > 0 && var.listen_port <= 65535
    error_message = "Listen port must be between 1 and 65535"
  }
}

variable "exporter_version" {
  description = "Pinned bigtcze pve-exporter release version"
  type        = string
  default     = "1.14.0"
}

variable "exporter_sha256" {
  description = "SHA256 checksum for the pinned bigtcze pve-exporter linux-amd64 binary"
  type        = string
  default     = "e5644b2dd9dcd337b9012bfa601d607d031d72fac760b6cf50750f5f9c663d3b"
}

variable "pve_host" {
  description = "Proxmox VE host address"
  type        = string
}

variable "pve_port" {
  description = "Proxmox VE API port"
  type        = number
  default     = 8006

  validation {
    condition     = var.pve_port > 0 && var.pve_port <= 65535
    error_message = "Proxmox VE API port must be between 1 and 65535"
  }
}

variable "pve_user" {
  description = "Proxmox VE user (e.g., root@pam or user@realm!token_name)"
  type        = string
}

variable "pve_password" {
  description = "Proxmox VE password or API token"
  type        = string
  sensitive   = true
}

variable "pve_verify_ssl" {
  description = "Whether to verify the Proxmox VE TLS certificate"
  type        = bool
  default     = false
}
