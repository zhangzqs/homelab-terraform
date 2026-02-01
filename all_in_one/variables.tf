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
