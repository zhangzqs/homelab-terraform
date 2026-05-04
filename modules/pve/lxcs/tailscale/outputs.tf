output "container_ip" {
  value       = var.ipv4_address
  description = "Tailscale容器的IPv4地址"
}

output "container_id" {
  value       = proxmox_virtual_environment_container.tailscale_container.id
  description = "Tailscale容器的ID"
}

output "container_vm_id" {
  value       = var.vm_id
  description = "Tailscale容器的VM ID"
}

output "container_password" {
  value       = random_password.container_password.result
  description = "Tailscale容器root用户密码"
  sensitive   = true
}

output "container_private_key" {
  value       = tls_private_key.container_key.private_key_pem
  description = "Tailscale容器SSH私钥"
  sensitive   = true
}

output "container_public_key" {
  value       = tls_private_key.container_key.public_key_openssh
  description = "Tailscale容器SSH公钥"
}

output "advertised_routes" {
  value       = var.tailscale_advertise_routes
  description = "Tailscale公告的子网路由列表"
}

output "metrics_endpoint" {
  value       = var.metrics_enabled ? "http://${var.ipv4_address}:${var.metrics_port}/metrics" : "Metrics disabled"
  description = "Prometheus metrics端点地址"
}

output "tailscale_hostname" {
  value       = var.tailscale_hostname != "" ? var.tailscale_hostname : var.hostname
  description = "Tailscale网络中的主机名"
}
