provider "proxmox" {
  endpoint = var.pve_endpoint
  username = var.pve_username
  password = var.pve_password
  insecure = var.pve_insecure

  ssh {
    username = "root"
    password = var.pve_password
  }
}
