variable "working_dir" {
  description = "工作目录"
  type        = string
  default     = "/root/mihomo"

  validation {
    condition     = can(regex("^/", var.working_dir))
    error_message = "工作目录必须是绝对路径（以 / 开头）"
  }
}

variable "mixed_port" {
  description = "混合代理端口"
  type        = number
  default     = 7890

  validation {
    condition     = var.mixed_port > 0 && var.mixed_port <= 65535
    error_message = "端口号必须在 1-65535 之间"
  }
}

variable "proxy_providers" {
  description = "机场订阅列表"
  type = map(object({
    url      = string
    interval = optional(number, 3600)
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.proxy_providers : can(regex("^https?://", v.url))])
    error_message = "所有订阅 URL 必须以 http:// 或 https:// 开头"
  }

  validation {
    condition     = alltrue([for k, v in var.proxy_providers : v.interval == null || (v.interval > 0 && v.interval <= 86400)])
    error_message = "更新间隔必须在 1-86400 秒之间（最多 24 小时）"
  }
}

variable "custom_proxies" {
  description = "自定义代理节点列表"
  type = map(object({
    type     = string
    server   = string
    port     = number
    password = string
    # 可以根据需要添加更多字段
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.custom_proxies : v.port > 0 && v.port <= 65535])
    error_message = "所有代理端口必须在 1-65535 之间"
  }

  validation {
    condition     = alltrue([for k, v in var.custom_proxies : length(v.password) > 0])
    error_message = "代理密码不能为空"
  }

  validation {
    condition     = alltrue([for k, v in var.custom_proxies : contains(["hysteria2", "vmess", "vless", "trojan", "ss", "ssr"], v.type)])
    error_message = "代理类型必须是支持的类型之一：hysteria2, vmess, vless, trojan, ss, ssr"
  }
}
