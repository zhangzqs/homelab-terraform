module "pve_lxc_instance_coredns" {
  source = "../pve/lxcs/coredns"

  pve_node_name            = local.pve_node_name
  hostname                 = "coredns"
  vm_id                    = local.pve_vm_id_lxc_coredns
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_lxc_coredns
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway
  working_dir              = "/root/coredns"

  # DNS配置
  dns_port     = 53
  metrics_port = 9153

  # 上游DNS服务器 - 支持普通DNS、DoH和DoT
  upstream_dns_servers = [
    "223.5.5.5",    # 阿里DNS
    "119.29.29.29", # 腾讯DNS
  ]

  # 缓存配置
  cache_ttl         = 3600
  cache_prefetch    = 10
  cache_serve_stale = 86400

  # 可选：Hosts记录（精确匹配）
  hosts = []

  # 可选：泛域名配置（支持*.example.com形式的通配符）
  wildcard_domains = [
    {
      zone = var.home_base_domain
      ip   = local.pve_vm_id_lxc_nginx
    }
  ]

  providers = {
    proxmox = proxmox
  }
}

output "pve_lxc_coredns_ipv4_address" {
  value       = module.pve_lxc_instance_coredns.container_ip
  description = "CoreDNS LXC容器IPv4地址"
}

output "pve_lxc_coredns_password" {
  value       = module.pve_lxc_instance_coredns.container_password
  description = "CoreDNS LXC容器用户密码"
  sensitive   = true
}
