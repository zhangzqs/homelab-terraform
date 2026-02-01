variable "pve_endpoint" {
  description = "Proxmox VE API 端点 URL"
  type        = string
}

variable "pve_username" {
  description = "Proxmox VE API 用户名"
  type        = string
  default     = "root@pam"
}

variable "pve_password" {
  description = "Proxmox VE API 用户密码"
  type        = string
}

variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

variable "pve_insecure" {
  description = "是否在连接 Proxmox VE API 时跳过 SSL 证书验证"
  type        = bool
  default     = true
}
