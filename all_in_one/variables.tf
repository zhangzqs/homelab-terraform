variable "pve_endpoint" {
  description = "Proxmox VE API 端点 URL"
  type        = string
}

variable "pve_password" {
  description = "Proxmox VE API 用户密码"
  type        = string
}

variable "mihomo_proxy_vars" {
  description = "Mihomo 代理配置变量"
  type = object({
    proxy_providers = optional(map(object({
      url = string
    })), {})
    custom_proxies = optional(map(object({
      type     = string
      server   = string
      port     = number
      password = string
    })), {})
  })
  default = {}
}

variable "network_ip_prefix" {
  description = "家庭网络IP前缀"
  type        = string
  default     = "192.168.242"

  // 必须有两个. 并且不能以.结尾
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){2}[0-9]{1,3}$", var.network_ip_prefix))
    error_message = "内网网段前缀格式不正确，必须是类似 192.168.242 的格式"
  }
}

variable "network_gateway" {
  description = "家庭网络网关IP地址"
  type        = string
  default     = "192.168.242.1"

  // 必须是有效的IPv4地址格式
  validation {
    condition     = can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}$", var.network_gateway))
    error_message = "网关IP地址格式不正确，必须是有效的IPv4地址"
  }
}
