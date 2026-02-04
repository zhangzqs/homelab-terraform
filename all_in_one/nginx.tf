module "nginx_config" {
  source = "../utils/nginx_config_generator"

  working_dir = "/root/nginx"

  services = {
    pve = {
      upstream_inline = {
        servers = [
          { address = trimsuffix(trimprefix(trimprefix(var.pve_endpoint, "https://"), "http://"), "/") }
        ]
      }
      domains = [
        {
          domain              = "pve.${var.home_base_domain}"
          http_enabled        = false
          https_enabled       = true
          ssl_certificate     = "/root/nginx/ssl/home_base_domain.crt"
          ssl_certificate_key = "/root/nginx/ssl/home_base_domain.key"
        }
      ]
    }
    code-server = {
      upstream_inline = {
        servers = [
          { address = "${module.pve_lxc_instance_code_server.container_ipv4_address}:${module.pve_lxc_instance_code_server.code_server_port}" }
        ]
      }
      domains = [
        {
          domain              = "code-server.${var.home_base_domain}"
          http_enabled        = false
          https_enabled       = true
          ssl_certificate     = "/root/nginx/ssl/home_base_domain.crt"
          ssl_certificate_key = "/root/nginx/ssl/home_base_domain.key"
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
  nginx_configs = merge({
    "nginx.conf"               = module.nginx_config.nginx_conf
    "conf.d/upstream.conf"     = module.nginx_config.upstream_conf
    "conf.d/servers.conf"      = module.nginx_config.servers_conf
    "ssl/home_base_domain.crt" = module.acme_certs.nginx_ssl_certificate
    "ssl/home_base_domain.key" = module.acme_certs.nginx_ssl_certificate_key
  })

  providers = {
    proxmox = proxmox
  }
}

output "pve_lxc_nginx_ipv4_address" {
  value       = module.pve_lxc_instance_nginx.container_ip
  description = "Nginx LXC容器IPv4地址"
}

output "pve_lxc_nginx_password" {
  value       = module.pve_lxc_instance_nginx.root_password
  description = "Nginx LXC容器用户密码"
  sensitive   = true
}
