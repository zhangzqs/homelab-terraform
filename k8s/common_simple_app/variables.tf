
variable "app_name" {
  description = "应用名称，用于标签和资源命名（必填）"
  type        = string
}

variable "namespace" {
  description = "Kubernetes 命名空间（可选，默认使用 app_name 变量的值）"
  type        = string
  default     = null
}

variable "pod_replicas" {
  description = "Pod 副本数量"
  type        = number
  default     = 1
}

variable "container_image" {
  description = "Docker 镜像地址（必填）"
  type        = string
}

variable "container_name" {
  description = "容器名称（可选，默认使用 app_name 变量的值）"
  type        = string
  default     = null
}

variable "container_env" {
  description = "容器环境变量列表"
  type        = map(string)
  default     = {}
}

variable "container_ports" {
  description = "容器端口列表"
  type = list(object({
    name           = string
    container_port = number
    protocol       = optional(string, "TCP")
  }))
  default = []
}

variable "container_resources" {
  description = "容器资源请求和限制"
  type = object({
    requests = object({
      cpu    = optional(string, "100m")
      memory = optional(string, "128Mi")
    })
    limits = object({
      cpu    = optional(string, "500m")
      memory = optional(string, "512Mi")
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "128Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "256Mi"
    }
  }
}

variable "service_ports" {
  description = "服务端口列表（可选，为空时不创建 Service 资源）"
  type = list(object({
    name        = string
    port        = number
    target_port = number
    protocol    = optional(string, "TCP")
  }))
  default = []
}

variable "liveness_probe" {
  description = "存活探针配置（可选）"
  type = object({
    enabled               = optional(bool, true)
    path                  = optional(string, "/")
    port                  = optional(number, 80)
    initial_delay_seconds = optional(number, 30)
    period_seconds        = optional(number, 10)
    timeout_seconds       = optional(number, 5)
    failure_threshold     = optional(number, 3)
  })
  default = {
    enabled               = true
    path                  = "/"
    port                  = 80
    initial_delay_seconds = 30
    period_seconds        = 10
    timeout_seconds       = 5
    failure_threshold     = 3
  }
}

variable "readiness_probe" {
  description = "就绪探针配置（可选）"
  type = object({
    enabled               = optional(bool, true)
    path                  = optional(string, "/")
    port                  = optional(number, 80)
    initial_delay_seconds = optional(number, 10)
    period_seconds        = optional(number, 5)
    timeout_seconds       = optional(number, 3)
    failure_threshold     = optional(number, 3)
  })
  default = {
    enabled               = true
    path                  = "/"
    port                  = 80
    initial_delay_seconds = 10
    period_seconds        = 5
    timeout_seconds       = 3
    failure_threshold     = 3
  }
}

variable "httproute_enabled" {
  description = "是否启用 HTTPRoute (Gateway API)"
  type        = bool
  default     = false
}

variable "httproute_hostnames" {
  description = "HTTPRoute 访问域名"
  type        = list(string)
  default     = []

  // 如果启用 HTTPRoute，则必须提供访问域名
  validation {
    condition     = !var.httproute_enabled || (var.httproute_enabled && length(var.httproute_hostnames) > 0)
    error_message = "如果启用 HTTPRoute，则必须提供访问域名"
  }
}

variable "httproute_rules" {
  description = "HTTPRoute 流量转发规则列表"
  type = list(object({
    matches = list(object({
      path = object({
        type  = optional(string, "PathPrefix")
        value = optional(string, "/")
      })
    }))
    backendRefs = list(object({
      name = string
      port = number
    }))
  }))
  default = []

  // 如果启用 HTTPRoute，则必须提供至少一条流量转发规则
  validation {
    condition     = !var.httproute_enabled || (var.httproute_enabled && length(var.httproute_rules) > 0)
    error_message = "如果启用 HTTPRoute，则必须提供至少一条流量转发规则"
  }
}

variable "gateway_name" {
  description = "Gateway 资源名称"
  type        = string
  default     = ""

  // 如果启用 HTTPRoute，则必须提供 Gateway 资源名称
  validation {
    condition     = !var.httproute_enabled || (var.httproute_enabled && length(var.gateway_name) > 0)
    error_message = "如果启用 HTTPRoute，则必须提供 Gateway 资源名称"
  }
}

variable "gateway_namespace" {
  description = "Gateway 所在命名空间"
  type        = string
  default     = ""

  // 如果启用 HTTPRoute，则必须提供 Gateway 所在命名空间
  validation {
    condition     = !var.httproute_enabled || (var.httproute_enabled && length(var.gateway_namespace) > 0)
    error_message = "如果启用 HTTPRoute，则必须提供 Gateway 所在命名空间"
  }
}
