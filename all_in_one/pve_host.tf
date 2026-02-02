
module "pve_host" {
  source = "../pve/host_configure"

  pve_node_name = local.pve_node_name

  providers = {
    proxmox = proxmox
  }
}

module "pve_lxc_templates" {
  source = "../pve/lxc_templates"

  pve_node_name = local.pve_node_name

  ubuntu_24_04_enabled      = true
  ubuntu_24_04_datastore_id = "local"

  providers = {
    proxmox = proxmox
  }
}

module "pve_vm_cloud_images" {
  source = "../pve/vm_cloud_images"

  pve_node_name = local.pve_node_name

  ubuntu_24_04_enabled      = true
  ubuntu_24_04_datastore_id = "local"

  providers = {
    proxmox = proxmox
  }
}
