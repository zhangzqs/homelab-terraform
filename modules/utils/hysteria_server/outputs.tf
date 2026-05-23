output "server_address" {
  description = "Hysteria 2 服务器地址"
  value       = "${var.ssh_host}:${var.listen_port}"
}

output "domain" {
  description = "Hysteria 2 服务域名"
  value       = var.domain
}
