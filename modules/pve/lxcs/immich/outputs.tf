output "container_ip" {
  value       = var.ipv4_address
  description = "Immich LXC 容器IPv4地址"
}

output "container_password" {
  value       = random_password.container_password.result
  description = "Immich LXC 容器root密码"
  sensitive   = true
}

output "container_private_key" {
  value       = tls_private_key.container_key.private_key_openssh
  description = "SSH私钥用于容器访问"
  sensitive   = true
}

output "immich_url" {
  value       = "http://${var.ipv4_address}:${var.immich_port}"
  description = "Immich 访问地址"
}
