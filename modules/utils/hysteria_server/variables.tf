variable "ssh_host" {
  description = "目标主机地址"
  type        = string
}

variable "ssh_port" {
  description = "SSH 端口"
  type        = number
  default     = 22
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
  description = "SSH 私钥内容（与 ssh_password 二选一）"
  type        = string
  sensitive   = true
  default     = null
}

variable "domain" {
  description = "Hysteria 2 服务域名（用于 ACME 证书申请）"
  type        = string
}

variable "acme_email" {
  description = "ACME 证书申请邮箱"
  type        = string
}

variable "auth_password" {
  description = "客户端认证密码"
  type        = string
  sensitive   = true
}

variable "listen_port" {
  description = "Hysteria 2 监听端口"
  type        = number
  default     = 443

  validation {
    condition     = var.listen_port > 0 && var.listen_port <= 65535
    error_message = "端口必须在 1-65535 之间"
  }
}

variable "masquerade_url" {
  description = "伪装目标 URL（对抗 DPI 审查）"
  type        = string
  default     = "https://www.bing.com/"
}
