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
  default     = false
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

variable "working_dir" {
  description = "Nginx工作目录"
  type        = string
  default     = "/root/nginx"
}

variable "access_log_path" {
  description = "访问日志文件路径"
  type        = string
  default     = "/root/nginx/logs/access.log"
}

variable "error_log_path" {
  description = "错误日志文件路径"
  type        = string
  default     = "/root/nginx/logs/error.log"
}

variable "error_log_level" {
  description = "错误日志级别"
  type        = string
  default     = "warn"

  validation {
    condition     = contains(["debug", "info", "notice", "warn", "error", "crit", "alert", "emerg"], var.error_log_level)
    error_message = "错误日志级别必须是: debug, info, notice, warn, error, crit, alert, emerg 之一"
  }
}

variable "shared_upstreams" {
  description = "共享的上游服务器配置（可被多个服务引用）"
  type = map(object({
    servers = list(object({
      address      = string
      max_fails    = optional(number, 3)
      fail_timeout = optional(string, "30s")
      weight       = optional(number, 1)
      backup       = optional(bool, false)
    }))
    keepalive         = optional(number, 32)
    keepalive_timeout = optional(string, "60s")
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, upstream in var.shared_upstreams : alltrue([
        for server in upstream.servers :
        !startswith(server.address, "http://") && !startswith(server.address, "https://")
      ])
    ])
    error_message = "upstream server的address不能以http://或https://开头，应直接使用IP:端口或域名:端口格式，例如：192.168.1.100:8080"
  }

  validation {
    condition = alltrue([
      for name, upstream in var.shared_upstreams : alltrue([
        for server in upstream.servers :
        server.max_fails >= 0 && server.max_fails <= 100
      ])
    ])
    error_message = "max_fails必须在0-100之间"
  }
}

variable "services" {
  description = "服务配置（支持内联upstream或引用shared_upstreams）"
  type = map(object({
    # Upstream配置（二选一）
    upstream_ref = optional(string, "") # 引用shared_upstreams中的upstream名称
    upstream_inline = optional(object({ # 内联upstream配置
      servers = list(object({
        address      = string
        max_fails    = optional(number, 3)
        fail_timeout = optional(string, "30s")
        weight       = optional(number, 1)
        backup       = optional(bool, false)
      }))
      keepalive         = optional(number, 32)
      keepalive_timeout = optional(string, "60s")
    }), null)

    domains = list(object({
      domain              = string
      http_enabled        = optional(bool, true)
      https_enabled       = optional(bool, false)
      ssl_certificate     = optional(string, "")
      ssl_certificate_key = optional(string, "")
    }))
    locations = optional(list(object({
      path       = string
      proxy_pass = optional(string, "") # 如果为空，则使用upstream
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
  }))
  default = {}

  validation {
    condition = alltrue([
      for name, service in var.services :
      (service.upstream_ref != "" && service.upstream_inline == null) ||
      (service.upstream_ref == "" && service.upstream_inline != null)
    ])
    error_message = "每个服务必须指定upstream_ref或upstream_inline，且只能二选一"
  }

  validation {
    condition = alltrue([
      for name, service in var.services :
      service.upstream_ref == "" || contains(keys(var.shared_upstreams), service.upstream_ref)
    ])
    error_message = "upstream_ref引用的upstream必须在shared_upstreams中定义"
  }

  validation {
    condition = alltrue([
      for name, service in var.services :
      service.upstream_inline == null || alltrue([
        for server in service.upstream_inline.servers :
        !startswith(server.address, "http://") && !startswith(server.address, "https://")
      ])
    ])
    error_message = "内联upstream server的address不能以http://或https://开头，应直接使用IP:端口或域名:端口格式，例如：192.168.1.100:8080"
  }

  validation {
    condition = alltrue([
      for name, service in var.services :
      service.upstream_inline == null || alltrue([
        for server in service.upstream_inline.servers :
        server.max_fails >= 0 && server.max_fails <= 100
      ])
    ])
    error_message = "内联upstream的max_fails必须在0-100之间"
  }
}

variable "ssl_common_config" {
  description = "通用SSL配置"
  type = object({
    protocols             = optional(string, "TLSv1.2 TLSv1.3")
    ciphers               = optional(string, "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256")
    prefer_server_ciphers = optional(bool, true)
    session_cache         = optional(string, "shared:SSL:10m")
    session_timeout       = optional(string, "10m")
  })
  default = {}
}
