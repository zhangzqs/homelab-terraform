output "container_ip" {
  value       = var.ipv4_address
  description = "Mihomo 容器的 IPv4 地址"
}

output "container_password" {
  value       = random_password.container_password.result
  description = "Mihomo 容器 root 用户密码"
  sensitive   = true
}

output "container_private_key" {
  value       = tls_private_key.container_key.private_key_openssh
  description = "Mihomo 容器 SSH 私钥"
  sensitive   = true
}
