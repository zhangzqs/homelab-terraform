module "pve_lxc_instance_storage_server" {
  source = "../pve/lxcs/storage_server"

  pve_node_name = local.pve_node_name

  hostname                 = "storage-server"
  vm_id                    = local.pve_vm_id_lxc_storage_server
  ubuntu_template_file_id  = module.pve_lxc_templates.ubuntu_24_04_id
  network_interface_bridge = local.pve_default_network_bridge
  ipv4_address             = local.pve_ipv4_address_lxc_nfs_server
  ipv4_address_cidr        = 24
  ipv4_gateway             = local.pve_default_ipv4_gateway
  disk_size                = 50
  enabled_protocols        = ["nfs", "smb"]

  nfs_exports = [
    {
      name = "test"
      path = "/root/test_nfs"
    },
  ]

  host_mount_points = [
    {
      host_path      = "/root/share"
      container_path = "/root/share"
    },
  ]

  smb_shares = [
    {
      name        = "test"
      path        = "/root/test_smb"
      valid_users = ["storageuser"]
      guest_ok    = false
      read_only   = false
    },
  ]

  providers = {
    proxmox = proxmox
  }
}

output "pve_lxc_storage_server_ipv4_address" {
  value       = local.pve_ipv4_address_lxc_nfs_server
  description = "Storage Server LXC 的 IPv4 地址"
}

output "pve_lxc_storage_server_password" {
  value       = module.pve_lxc_instance_storage_server.container_password
  description = "Storage Server LXC 的默认用户密码"
  sensitive   = true
}
