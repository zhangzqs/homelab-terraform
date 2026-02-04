module "nginx_config" {
  source = "../utils/nginx_config_generator"

  working_dir = "/root/nginx"

  services = {
    code-server = {
      upstream_inline = {
        servers = [
          {
            address = "${module.pve_lxc_instance_code_server.container_ipv4_address}:${module.pve_lxc_instance_code_server.code_server_port}"
          }
        ]
      }
      domains = [
        {
          domain       = "code-server.my-domain.local"
          http_enabled = true
        }
      ]
    }
  }
}

module "pve_lxc_instance_nginx" {
  source = "../pve/lxcs/nginx"

  pve_node_name = local.pve_node_name

  hostname                 = "nginx"
  vm_id                    = local.pve_vm_id_lxc_nginx
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_lxc_nginx
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway
  working_dir              = "/root/nginx"
  nginx_configs            = module.nginx_config.all_configs

  providers = {
    proxmox = proxmox
  }
}
