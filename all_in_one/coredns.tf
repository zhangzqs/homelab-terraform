module "pve_lxc_instance_coredns" {
  source = "../pve/lxcs/coredns"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password

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

  # 可选：自定义hosts记录
  custom_hosts = []
}

output "coredns_dns_address" {
  value       = module.pve_lxc_instance_coredns.dns_address
  description = "CoreDNS DNS服务地址"
}

output "coredns_metrics_address" {
  value       = module.pve_lxc_instance_coredns.metrics_address
  description = "CoreDNS Prometheus metrics地址"
}
