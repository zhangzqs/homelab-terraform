output "mount_point" {
  description = "挂载点路径"
  value       = var.mount_point
}

output "disk_uuid" {
  description = "磁盘UUID"
  value       = var.disk_uuid
}

output "mount_unit_name" {
  description = "Systemd mount 单元名称"
  value       = local.mount_unit_name
}

output "automount_unit_name" {
  description = "Systemd automount 单元名称"
  value       = local.automount_unit_name
}

output "automount_enabled" {
  description = "是否启用了自动挂载"
  value       = var.automount_enabled
}

output "management_commands" {
  description = "管理命令"
  value = var.automount_enabled ? {
    status  = "systemctl status ${local.automount_unit_name}"
    start   = "systemctl start ${local.automount_unit_name}"
    stop    = "systemctl stop ${local.automount_unit_name}"
    restart = "systemctl restart ${local.automount_unit_name}"
    enable  = "systemctl enable ${local.automount_unit_name}"
    disable = "systemctl disable ${local.automount_unit_name}"
  } : {
    status  = "systemctl status ${local.mount_unit_name}"
    start   = "systemctl start ${local.mount_unit_name}"
    stop    = "systemctl stop ${local.mount_unit_name}"
    restart = "systemctl restart ${local.mount_unit_name}"
    enable  = "systemctl enable ${local.mount_unit_name}"
    disable = "systemctl disable ${local.mount_unit_name}"
  }
}
