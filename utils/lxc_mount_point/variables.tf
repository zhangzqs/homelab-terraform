# ==========================================
# SSH 连接参数
# ==========================================

variable "ssh_host" {
  type        = string
  description = "Proxmox VE 宿主机的 SSH 地址"
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH 端口号"
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "SSH 用户名"
}

variable "ssh_password" {
  type        = string
  default     = null
  sensitive   = true
  description = "SSH 密码（与 ssh_private_key 二选一）"
}

variable "ssh_private_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "SSH 私钥路径或内容（与 ssh_password 二选一）"
}

# ==========================================
# LXC 容器配置
# ==========================================

variable "container_id" {
  type        = number
  description = "LXC 容器的 ID"

  validation {
    condition     = var.container_id > 0 && var.container_id < 1000000
    error_message = "容器 ID 必须是有效的正整数"
  }
}

variable "mount_point_id" {
  type        = string
  default     = "mp0"
  description = "挂载点 ID，格式为 mpN (N=0-9)"

  validation {
    condition     = can(regex("^mp[0-9]$", var.mount_point_id))
    error_message = "挂载点 ID 格式必须为 mpN，其中 N 是 0-9 的数字"
  }
}

# ==========================================
# 挂载路径配置
# ==========================================

variable "host_path" {
  type        = string
  description = "宿主机上的目录路径（必须是绝对路径）"

  validation {
    condition     = can(regex("^/", var.host_path))
    error_message = "宿主机路径必须是绝对路径（以 / 开头）"
  }
}

variable "container_path" {
  type        = string
  description = "容器内的挂载点路径（必须是绝对路径）"

  validation {
    condition     = can(regex("^/", var.container_path))
    error_message = "容器路径必须是绝对路径（以 / 开头）"
  }
}

# ==========================================
# 挂载选项
# ==========================================

variable "mount_options" {
  type        = list(string)
  default     = []
  description = "挂载选项列表，如 ['backup=1', 'replicate=1']"
}

# ==========================================
# 容器操作选项
# ==========================================

variable "restart_container" {
  type        = bool
  default     = true
  description = "挂载后是否重启容器使配置生效"
}

variable "stop_before_mount" {
  type        = bool
  default     = false
  description = "挂载前是否先停止容器"
}
