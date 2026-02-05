variable "httproute_hostname" {
  description = "HTTPRoute 访问域名"
  type        = string
  default     = "speedtest.example.com"
}

variable "gateway_name" {
  description = "Gateway 资源名称"
  type        = string
}

variable "gateway_namespace" {
  description = "Gateway 所在命名空间"
  type        = string
}
