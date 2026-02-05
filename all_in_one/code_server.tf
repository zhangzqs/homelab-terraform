module "pve_lxc_instance_code_server" {
  source = "../pve/lxcs/code_server"

  pve_node_name = local.pve_node_name

  vm_id                    = local.pve_vm_id_lxc_code_server
  network_interface_bridge = local.pve_default_network_bridge
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  working_dir              = "/root/code-server"
  code_server_port         = 8080

  ipv4_address      = local.pve_ipv4_address_lxc_code_server
  ipv4_address_cidr = 24
  ipv4_gateway      = local.pve_default_ipv4_gateway

  install_proxy = {
    http_proxy  = local.mihomo_http_proxy_address
    https_proxy = local.mihomo_http_proxy_address
  }
  code_server_password = var.code_server_password

  providers = {
    proxmox = proxmox
  }
}
