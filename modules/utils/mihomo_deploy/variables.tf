variable "ssh_host" {
  description = "目标主机地址"
  type        = string
}

variable "ssh_port" {
  description = "SSH 端口"
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "SSH 端口必须在 1-65535 之间"
  }
}

variable "ssh_user" {
  description = "SSH 用户名"
  type        = string
  default     = "root"
}

variable "ssh_password" {
  description = "SSH 密码（与 ssh_private_key 二选一）"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key" {
  description = "SSH 私钥内容或文件路径（与 ssh_password 二选一，推荐使用私钥）"
  type        = string
  sensitive   = true
  default     = null
}

variable "working_dir" {
  description = "mihomo 工作目录"
  type        = string
  default     = "/root/mihomo"

  validation {
    condition     = can(regex("^/", var.working_dir))
    error_message = "工作目录必须是绝对路径（以 / 开头）"
  }
}

variable "mihomo_download_url" {
  description = "mihomo deb 包下载地址"
  type        = string
  // v1.19.27 起官方 deb 默认带 openvpn 支持；v1.19.19 没有，无法解析
  // proxy.type=openvpn 的配置
  default = "https://gh-proxy.org/https://github.com/MetaCubeX/mihomo/releases/download/v1.19.27/mihomo-linux-amd64-v2-v1.19.27.deb"
}

variable "mihomo_config_content" {
  description = "mihomo 配置文件内容 (config.yaml)"
  type        = string
  default     = "port: 7890"
}

variable "extra_triggers" {
  description = "额外的触发器映射，任意值变化时将重新触发安装和配置。用于在上层模块中传递容器/实例重建信号"
  type        = map(string)
  default     = {}
}
