output "container_ip" {
  value       = var.ipv4_address
  description = "容器IP地址"
}

output "container_password" {
  value       = random_password.container_password.result
  description = "LXC容器用户密码"
  sensitive   = true
}

output "ssh_private_key" {
  value       = tls_private_key.container_key.private_key_pem
  description = "SSH私钥用于容器访问"
  sensitive   = true
}

output "dns_address" {
  value       = "${var.ipv4_address}:${var.dns_port}"
  description = "CoreDNS DNS服务地址"
}

output "metrics_address" {
  value       = "http://${var.ipv4_address}:${var.metrics_port}/metrics"
  description = "CoreDNS Prometheus metrics地址"
}

output "working_dir" {
  value       = var.working_dir
  description = "CoreDNS工作目录（日志和缓存存储位置）"
}
