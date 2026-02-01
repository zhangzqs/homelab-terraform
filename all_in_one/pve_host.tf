
module "pve_host" {
  source = "../pve/host_configure"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password
}

module "pve_lxc_templates" {
  source = "../pve/lxc_templates"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password

  ubuntu_24_04_enabled      = true
  ubuntu_24_04_datastore_id = "local"
}

module "pve_vm_cloud_images" {
  source = "../pve/vm_cloud_images"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password

  ubuntu_24_04_enabled      = true
  ubuntu_24_04_datastore_id = "local"
}
