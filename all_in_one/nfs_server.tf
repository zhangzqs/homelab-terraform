
module "pve_lxc_nfs_server" {
  source = "../pve/lxcs/nfs_server"

  pve_node_name = local.pve_node_name
  pve_endpoint  = var.pve_endpoint
  pve_username  = local.pve_username
  pve_password  = var.pve_password

  hostname                 = "nfs-server"
  vm_id                    = local.pve_vm_id_lxc_nfs_server
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_lxc_nfs_server
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway
  nfs_export_path          = "/srv/nfs/k3s"
  nfs_allowed_network      = "192.168.242.0/24"
  disk_size                = 50
}

output "pve_lxc_nfs_server_ipv4_address" {
  value       = local.pve_ipv4_address_lxc_nfs_server
  description = "NFS Server LXC 容器的 IPv4 地址"
}

output "pve_lxc_nfs_server_password" {
  value       = module.pve_lxc_nfs_server.container_password
  description = "NFS Server LXC 容器的 root 密码"
  sensitive   = true
}

output "pve_lxc_nfs_server_export_path" {
  value       = module.pve_lxc_nfs_server.nfs_export_path
  description = "NFS 服务器导出路径"
}
