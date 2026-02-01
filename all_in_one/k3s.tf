
module "pve_vm_k3s_master" {
  source = "../pve/vms/k3s_master"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password

  vm_id                    = local.pve_vm_id_vm_k3s_master
  ubuntu_cloud_image_id    = module.pve_vm_cloud_images.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_vm_k3s_master
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway

  containerd_proxy = {
    http_proxy  = local.mihomo_http_proxy_address
    https_proxy = local.mihomo_http_proxy_address
  }
}
