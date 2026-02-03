variable "gateway_api_namespace" {
  description = "Gateway API 命名空间"
  type        = string
  default     = "nginx-gateway"
}

variable "nginx_gateway_fabric_chart_version" {
  description = "NGINX Gateway Fabric Helm Chart 版本"
  type        = string
  default     = "1.6.2"
}

variable "gateway_name" {
  description = "Gateway 资源名称"
  type        = string
  default     = "nginx-gateway"
}

variable "gateway_service_type" {
  description = "Gateway Service 类型 (NodePort, LoadBalancer)"
  type        = string
  default     = "NodePort"
}

variable "gateway_http_nodeport" {
  description = "HTTP NodePort 端口号"
  type        = number
  default     = 30080
}

variable "gateway_https_nodeport" {
  description = "HTTPS NodePort 端口号"
  type        = number
  default     = 30443
}
