variable "ssh_host" {
  description = "目标主机地址"
  type        = string
}

variable "ssh_port" {
  description = "SSH端口"
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "SSH端口必须在1-65535之间"
  }
}

variable "ssh_user" {
  description = "SSH用户名"
  type        = string
  default     = "root"
}

variable "ssh_password" {
  description = "SSH密码（与ssh_private_key二选一）"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key" {
  description = "SSH私钥内容或文件路径（与ssh_password二选一，推荐使用私钥）"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key_path" {
  description = "SSH私钥文件路径（可选，用于指定密钥文件路径）"
  type        = string
  default     = null
}

variable "disk_uuid" {
  description = "磁盘UUID（通过 blkid 命令获取）"
  type        = string

  validation {
    condition     = length(var.disk_uuid) > 0
    error_message = "磁盘UUID不能为空"
  }
}

variable "disk_label" {
  description = "磁盘标签（用于systemd单元命名）"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.disk_label))
    error_message = "磁盘标签只能包含字母、数字、下划线和连字符"
  }
}

variable "mount_point" {
  description = "挂载点路径"
  type        = string

  validation {
    condition     = can(regex("^/[a-zA-Z0-9/_-]*$", var.mount_point))
    error_message = "挂载点必须是有效的绝对路径"
  }
}

variable "filesystem_type" {
  description = "文件系统类型"
  type        = string
  default     = "ext4"

  validation {
    condition     = contains(["ext4", "ext3", "ext2", "xfs", "btrfs", "ntfs", "exfat", "vfat", "f2fs"], var.filesystem_type)
    error_message = "文件系统类型必须是: ext4, ext3, ext2, xfs, btrfs, ntfs, exfat, vfat, f2fs 之一"
  }
}

variable "mount_options" {
  description = "挂载选项"
  type        = string
  default     = "defaults,nofail"
}

variable "automount_enabled" {
  description = "是否启用自动挂载（true: 按需挂载, false: 立即挂载）"
  type        = bool
  default     = true
}

variable "automount_timeout" {
  description = "自动卸载超时时间（秒），0表示永不超时"
  type        = number
  default     = 300

  validation {
    condition     = var.automount_timeout >= 0
    error_message = "超时时间必须大于等于0"
  }
}

variable "owner" {
  description = "挂载点所有者"
  type        = string
  default     = "root"
}

variable "group" {
  description = "挂载点所属组"
  type        = string
  default     = "root"
}

variable "permissions" {
  description = "挂载点权限（八进制格式字符串，如 '755'）"
  type        = string
  default     = "755"

  validation {
    condition     = can(regex("^[0-7]{3,4}$", var.permissions))
    error_message = "权限必须是3-4位八进制数字，如 '755' 或 '0755'"
  }
}
