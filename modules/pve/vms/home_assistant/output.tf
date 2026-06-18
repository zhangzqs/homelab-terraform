output "vm_id" {
  description = "Home Assistant 虚拟机 ID"
  value       = proxmox_virtual_environment_vm.home_assistant.vm_id
}

output "vm_ip" {
  description = "Home Assistant 虚拟机 IPv4 地址（由 CONFIG ISO 注入的静态 IP）"
  value       = var.ipv4_address
}

output "ha_url" {
  description = "Home Assistant Web UI 访问地址"
  value       = "http://${var.ipv4_address}:8123"
}

output "config_iso_file_id" {
  description = "CONFIG 注入 ISO 在 PVE 中的 file id"
  value       = local.config_iso_file_id
}
