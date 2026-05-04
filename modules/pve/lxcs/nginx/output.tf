output "container_id" {
  description = "LXC容器的ID"
  value       = proxmox_virtual_environment_container.nginx_container.id
}

output "container_vmid" {
  description = "LXC容器的VMID"
  value       = var.vm_id
}

output "container_ip" {
  description = "LXC容器的IP地址"
  value       = var.ipv4_address
}

output "hostname" {
  description = "容器的主机名"
  value       = var.hostname
}

output "ssh_private_key" {
  description = "SSH私钥(敏感)"
  value       = tls_private_key.container_key.private_key_pem
  sensitive   = true
}

output "root_password" {
  description = "Root密码(敏感)"
  value       = random_password.container_password.result
  sensitive   = true
}
