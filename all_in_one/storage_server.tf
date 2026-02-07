variable "pve_host_ssh_params" {
  type = object({
    ssh_host     = string
    ssh_port     = optional(number, 22)
    ssh_user     = optional(string, "root")
    ssh_password = string
  })
  description = "Proxmox VE 主机的 SSH 连接参数"
}

module "auto_disk_mount" {
  source       = "../utils/auto_disk_mount"
  ssh_host     = var.pve_host_ssh_params.ssh_host
  ssh_port     = var.pve_host_ssh_params.ssh_port
  ssh_user     = var.pve_host_ssh_params.ssh_user
  ssh_password = var.pve_host_ssh_params.ssh_password

  disk_uuid         = var.hdd_disk_uuid # 替换为实际的UUID（使用 blkid 命令查看）
  disk_label        = "hdd-disk"
  mount_point       = "/mnt/hdd-disk"
  filesystem_type   = "ext4"
  mount_options     = "defaults,nofail" // 开机自动挂载，磁盘不可用时不影响系统启动
  automount_enabled = true              // 启用按需挂载
  automount_timeout = 300               // 秒，0表示永不超时卸载
}

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
      name = "k8s_volumes"
      path = local.k8s_volumes_nfs_path
    },
  ]

  host_mount_points = [
    {
      host_path      = module.auto_disk_mount.mount_point
      container_path = "/mnt/host_hdd_disk"
    }
  ]
  providers = {
    proxmox = proxmox
  }
}

module "pvc_lxc_mount_point_storage_server" {
  source = "../utils/lxc_mount_point"
  depends_on = [
    module.pve_lxc_instance_storage_server
  ]

  ssh_host     = var.pve_host_ssh_params.ssh_host
  ssh_port     = var.pve_host_ssh_params.ssh_port
  ssh_user     = var.pve_host_ssh_params.ssh_user
  ssh_password = var.pve_host_ssh_params.ssh_password

  container_id   = local.pve_vm_id_lxc_storage_server
  mount_point_id = "mp0"
  host_path      = module.auto_disk_mount.mount_point
  container_path = "/mnt/host_hdd_disk"
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
