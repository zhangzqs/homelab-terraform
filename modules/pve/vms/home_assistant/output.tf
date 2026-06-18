output "vm_id" {
  description = "Home Assistant 虚拟机 ID"
  value       = proxmox_virtual_environment_vm.home_assistant.vm_id
}

output "vm_ip" {
  description = "Home Assistant 虚拟机 IPv4 地址（由 nmcli 注入的静态 IP）"
  value       = var.ipv4_address
}

output "ha_url" {
  description = "Home Assistant Web UI 访问地址"
  value       = "http://${var.ipv4_address}:8123"
}
