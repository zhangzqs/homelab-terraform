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

output "nfs_server_ip" {
  value       = var.ipv4_address
  description = "NFS 服务器 IP 地址"
}

output "nfs_export_path" {
  value       = var.nfs_export_path
  description = "NFS 导出路径"
}
