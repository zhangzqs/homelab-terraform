variable "worker_processes" {
  description = "Nginx worker进程数"
  type        = string
  default     = "auto"
}

variable "worker_connections" {
  description = "每个worker进程的最大连接数"
  type        = number
  default     = 102400

  validation {
    condition     = var.worker_connections > 0 && var.worker_connections <= 1048576
    error_message = "worker_connections必须在1-1048576之间"
  }
}

variable "enable_vts" {
  description = "是否启用VTS状态监控模块"
  type        = bool
  default     = true
}

variable "vts_status_port" {
  description = "VTS状态监控端口"
  type        = number
  default     = 80

  validation {
    condition     = var.vts_status_port > 0 && var.vts_status_port <= 65535
    error_message = "端口号必须在1-65535之间"
  }
}

variable "enable_gzip" {
  description = "是否启用gzip压缩"
  type        = bool
  default     = true
}

variable "log_format" {
  description = "日志格式类型"
  type        = string
  default     = "json"

  validation {
    condition     = contains(["json", "standard"], var.log_format)
    error_message = "日志格式必须是json或standard"
  }
}

variable "upstreams" {
  description = "上游服务器配置"
  type = map(object({
    servers = list(object({
      address    = string
      port       = number
      max_fails  = optional(number, 3)
      fail_timeout = optional(string, "30s")
      weight     = optional(number, 1)
      backup     = optional(bool, false)
    }))
    keepalive = optional(number, 32)
    keepalive_timeout = optional(string, "60s")
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, upstream in var.upstreams : alltrue([
        for server in upstream.servers :
          server.port > 0 && server.port <= 65535
      ])
    ])
    error_message = "所有上游服务器端口必须在1-65535之间"
  }

  validation {
    condition = alltrue([
      for name, upstream in var.upstreams : alltrue([
        for server in upstream.servers :
          server.max_fails >= 0 && server.max_fails <= 100
      ])
    ])
    error_message = "max_fails必须在0-100之间"
  }
}

variable "services" {
  description = "服务配置"
  type = map(object({
    upstream = string  # 对应的upstream名称
    domains = list(object({
      domain        = string
      http_enabled  = optional(bool, true)
      https_enabled = optional(bool, false)
      ssl_certificate     = optional(string, "")
      ssl_certificate_key = optional(string, "")
    }))
    locations = optional(list(object({
      path         = string
      proxy_pass   = optional(string, "")  # 如果为空，则使用upstream
      custom_config = optional(string, "")
    })), [])

    # 代理配置
    proxy_config = optional(object({
      enable_websocket     = optional(bool, true)
      connect_timeout      = optional(string, "200ms")
      read_timeout         = optional(string, "1000s")
      send_timeout         = optional(string, "1000s")
      client_max_body_size = optional(string, "8192M")
      proxy_buffering      = optional(bool, false)
    }), {})

    # 自定义配置片段
    custom_server_config = optional(string, "")
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, service in var.services :
        contains(keys(var.upstreams), service.upstream) || service.upstream == ""
    ])
    error_message = "服务引用的upstream必须在upstreams变量中定义"
  }
}

variable "ssl_common_config" {
  description = "通用SSL配置"
  type = object({
    protocols           = optional(string, "TLSv1.2 TLSv1.3")
    ciphers            = optional(string, "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256")
    prefer_server_ciphers = optional(bool, true)
    session_cache      = optional(string, "shared:SSL:10m")
    session_timeout    = optional(string, "10m")
  })
  default = {}
}

variable "custom_global_config" {
  description = "自定义全局配置（插入到http块中）"
  type        = string
  default     = ""
}
