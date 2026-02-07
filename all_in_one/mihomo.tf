
module "mihomo_proxy_config" {
  source = "../utils/mihomo_config_generator"

  mixed_port      = 7890
  proxy_providers = var.mihomo_proxy_vars.proxy_providers
  custom_proxies  = var.mihomo_proxy_vars.custom_proxies
}

module "pve_lxc_instance_mihomo" {
  depends_on = [module.mihomo_proxy_config]
  source     = "../pve/lxcs/mihomo_proxy"

  pve_node_name = local.pve_node_name

  hostname                 = "mihomo-proxy"
  vm_id                    = local.pve_vm_id_lxc_mihomo_proxy
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_lxc_mihomo_proxy
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway
  working_dir              = "/root/mihomo"
  mihomo_config_content    = module.mihomo_proxy_config.config_content

  providers = {
    proxmox = proxmox
  }
}

locals {
  mihomo_http_proxy_address = "http://${local.pve_ipv4_address_lxc_mihomo_proxy}:7890"
}
