module "pve_lxc_instance_tailscale" {
  source = "../pve/lxcs/tailscale"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password

  hostname                 = "tailscale"
  vm_id                    = local.pve_vm_id_lxc_tailscale
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_lxc_tailscale
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway

  # Tailscale配置
  tailscale_auth_key = var.tailscale_auth_key

  # 子网路由配置 - 暴露你的内网子网
  # 示例：["192.168.1.0/24", "10.0.0.0/16"]
  # 你需要在Tailscale管理后台批准这些路由
  tailscale_advertise_routes = [
    "${var.network_ip_prefix}.0/24"
  ]

  tailscale_hostname      = "homelab-tailscale"
  tailscale_accept_routes = true
  tailscale_exit_node     = true
  tailscale_ssh_enabled   = true

  # Prometheus监控
  metrics_enabled = true
  metrics_port    = 9001
}

output "pve_lxc_tailscale_ipv4_address" {
  value       = module.pve_lxc_instance_tailscale.container_ip
  description = "Tailscale LXC容器IPv4地址"
}

output "pve_lxc_tailscale_password" {
  value       = module.pve_lxc_instance_tailscale.container_password
  description = "Tailscale LXC容器root密码"
  sensitive   = true
}
