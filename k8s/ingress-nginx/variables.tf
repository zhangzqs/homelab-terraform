variable "ingress_nginx_namespace" {
  description = "Ingress Nginx 命名空间"
  type        = string
  default     = "ingress-nginx"
}

variable "ingress_nginx_chart_version" {
  description = "Ingress Nginx Helm Chart 版本"
  type        = string
  default     = "4.14.2"
}

variable "ingress_nginx_service_type" {
  description = "Ingress Nginx Service 类型 (NodePort, LoadBalancer)"
  type        = string
  default     = "NodePort"
}

variable "ingress_nginx_http_nodeport" {
  description = "HTTP NodePort 端口号"
  type        = number
  default     = 30080
}

variable "ingress_nginx_https_nodeport" {
  description = "HTTPS NodePort 端口号"
  type        = number
  default     = 30443
}
