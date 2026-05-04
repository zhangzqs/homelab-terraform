output "container_id" {
  value       = var.container_id
  description = "LXC 容器 ID"
}

output "mount_point_id" {
  value       = var.mount_point_id
  description = "挂载点 ID"
}

output "host_path" {
  value       = var.host_path
  description = "宿主机路径"
}

output "container_path" {
  value       = var.container_path
  description = "容器内挂载点路径"
}

output "mount_config" {
  value       = local.mount_config_string
  description = "完整的挂载配置字符串"
}
