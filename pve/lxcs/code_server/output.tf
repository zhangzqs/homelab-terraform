output "container_ipv4_address" {
  value       = var.ipv4_address
  description = "容器IP地址"
}

output "container_password" {
  value       = random_password.container_password.result
  description = "LXC容器用户密码"
  sensitive   = true
}

output "code_server_url" {
  value       = "http://${var.ipv4_address}:${var.code_server_port}"
  description = "Code Server访问地址"
}

output "code_server_password" {
  value       = local.code_server_password
  description = "Code Server访问密码"
  sensitive   = true
}

output "code_server_port" {
  value       = var.code_server_port
  description = "code-server 监听端口"
}

output "ssh_private_key" {
  value       = tls_private_key.container_key.private_key_pem
  description = "SSH私钥用于容器访问"
  sensitive   = true
}
