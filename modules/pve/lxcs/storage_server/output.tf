output "container_password" {
  value       = random_password.container_password.result
  description = "容器 root 用户密码"
  sensitive   = true
}

output "container_private_key" {
  value       = tls_private_key.container_key.private_key_pem
  description = "容器 SSH 私钥"
  sensitive   = true
}

output "container_public_key" {
  value       = tls_private_key.container_key.public_key_openssh
  description = "容器 SSH 公钥"
}

output "server_ip" {
  value       = var.ipv4_address
  description = "存储服务器 IP 地址"
}

output "enabled_protocols" {
  value       = var.enabled_protocols
  description = "启用的存储协议"
}

# NFS 相关输出
output "nfs_enabled" {
  value       = contains(var.enabled_protocols, "nfs")
  description = "是否启用 NFS 协议"
}

output "nfs_exports" {
  value = contains(var.enabled_protocols, "nfs") ? [
    for export in var.nfs_exports : {
      name            = export.name
      path            = export.path
      allowed_network = export.allowed_network
      options         = export.options != null ? export.options : "rw,sync,no_subtree_check,no_root_squash"
      mount_command   = "mount -t nfs ${var.ipv4_address}:${export.path} /mnt"
    }
  ] : null
  description = "NFS 导出配置列表（仅在启用 NFS 时有效）"
}

# SMB 相关输出
output "smb_enabled" {
  value       = contains(var.enabled_protocols, "smb")
  description = "是否启用 SMB 协议"
}

output "smb_shares" {
  value = contains(var.enabled_protocols, "smb") ? [
    for share in var.smb_shares : {
      name          = share.name
      path          = share.path
      read_only     = share.read_only != null ? share.read_only : false
      mount_command = "mount -t cifs //${var.ipv4_address}/${share.name} /mnt -o username=USER,password=PASS"
    }
  ] : null
  description = "SMB 共享配置列表（仅在启用 SMB 时有效）"
}

# 宿主机挂载点输出
output "host_mount_points" {
  value = length(var.host_mount_points) > 0 ? [
    for mp in var.host_mount_points : {
      host_path      = mp.host_path
      container_path = mp.container_path
      read_only      = mp.read_only != null ? mp.read_only : false
      shared         = mp.shared != null ? mp.shared : false
      backup         = mp.backup != null ? mp.backup : false
    }
  ] : null
  description = "宿主机到容器的挂载点列表"
}

