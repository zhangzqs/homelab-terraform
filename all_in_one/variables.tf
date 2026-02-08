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

# Tailscale配置变量
variable "tailscale_auth_key" {
  description = "Tailscale认证密钥(authkey)，从Tailscale管理后台生成"
  type        = string
  sensitive   = true
}

# acme.sh配置变量
variable "acme_sh_email" {
  description = "acme.sh注册使用的邮箱地址"
  type        = string
}

# acme.sh供应商
variable "acme_sh_dns_provider" {
  description = "acme.sh使用的DNS API供应商名称，例如：dns_cf、dns_aws等"
  type        = string
}

# acme.sh供应商配置参数，格式为JSON字符串，不同供应商需要的参数不同
variable "acme_sh_dns_provider_config" {
  description = "acme.sh使用的DNS API供应商配置参数，格式为JSON字符串，例如：{\"CF_Key\":\"your_cloudflare_api_key\",\"CF_Email\":\"your_email\"}"
  type        = map(string)
  sensitive   = true
}

# 家庭网络DNS泛域名
variable "home_base_domain" {
  description = "家庭网络使用的DNS泛域名，例如：home.example.com，表示所有*.home.example.com的域名都解析到家庭网络"
  type        = string
}

# code-server访问密码
variable "code_server_password" {
  description = "code-server访问密码"
  type        = string
  sensitive   = true
}

variable "hdd_disk_uuid" {
  description = "HDD磁盘的UUID，用于自动挂载"
  type        = string
}

variable "smb_hdd_password" {
  description = "SMB共享使用的密码"
  type        = string
  sensitive   = true
}
