terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~>3.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>3.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.pve_endpoint
  username = local.pve_username
  password = var.pve_password
  insecure = true

  ssh {
    username = "root"
    password = var.pve_password
  }
}
