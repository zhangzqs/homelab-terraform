variable "speedtest_image" {
  description = "LibreSpeed Speedtest Docker 镜像"
  type        = string
  default     = "ghcr.io/librespeed/speedtest:5.4.1"
}

variable "speedtest_replicas" {
  description = "Speedtest 服务器副本数量"
  type        = number
  default     = 1
}

variable "speedtest_service_type" {
  description = "Speedtest 服务类型 (ClusterIP, NodePort, LoadBalancer)"
  type        = string
  default     = "ClusterIP"
}

variable "speedtest_service_port" {
  description = "Speedtest 服务端口"
  type        = number
  default     = 80
}

variable "speedtest_mode" {
  description = "运行模式: standalone (默认) 或 backend"
  type        = string
  default     = "standalone"
}

variable "speedtest_telemetry" {
  description = "是否启用遥测数据收集 (true/false)"
  type        = string
  default     = "false"
}

variable "speedtest_password" {
  description = "管理员密码（用于查看遥测数据，如果启用）"
  type        = string
  default     = ""
  sensitive   = true
}

variable "speedtest_email" {
  description = "管理员邮箱（可选）"
  type        = string
  default     = ""
}

variable "speedtest_cpu_request" {
  description = "Speedtest CPU 请求量"
  type        = string
  default     = "100m"
}

variable "speedtest_cpu_limit" {
  description = "Speedtest CPU 限制量"
  type        = string
  default     = "500m"
}

variable "speedtest_memory_request" {
  description = "Speedtest 内存请求量"
  type        = string
  default     = "128Mi"
}

variable "speedtest_memory_limit" {
  description = "Speedtest 内存限制量"
  type        = string
  default     = "256Mi"
}

variable "speedtest_httproute_host" {
  description = "Speedtest HTTPRoute 访问域名"
  type        = string
  default     = "speedtest.example.com"
}

variable "speedtest_enable_httproute" {
  description = "是否启用 HTTPRoute (Gateway API)"
  type        = bool
  default     = false
}

variable "gateway_name" {
  description = "Gateway 资源名称"
  type        = string
  default     = "nginx-gateway"
}

variable "gateway_namespace" {
  description = "Gateway 所在命名空间"
  type        = string
  default     = "nginx-gateway"
}
