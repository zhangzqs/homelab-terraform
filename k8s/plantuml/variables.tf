variable "plantuml_image" {
  description = "PlantUML 服务器 Docker 镜像"
  type        = string
  default     = "plantuml/plantuml-server:jetty-v1.2025.2"
}

variable "plantuml_replicas" {
  description = "PlantUML 服务器副本数量"
  type        = number
  default     = 1
}

variable "plantuml_service_type" {
  description = "PlantUML 服务类型 (ClusterIP, NodePort, LoadBalancer)"
  type        = string
  default     = "ClusterIP"
}

variable "plantuml_service_port" {
  description = "PlantUML 服务端口"
  type        = number
  default     = 8080
}

variable "plantuml_cpu_request" {
  description = "PlantUML CPU 请求量"
  type        = string
  default     = "100m"
}

variable "plantuml_cpu_limit" {
  description = "PlantUML CPU 限制量"
  type        = string
  default     = "500m"
}

variable "plantuml_memory_request" {
  description = "PlantUML 内存请求量"
  type        = string
  default     = "256Mi"
}

variable "plantuml_memory_limit" {
  description = "PlantUML 内存限制量"
  type        = string
  default     = "512Mi"
}

variable "plantuml_ingress_host" {
  description = "PlantUML Ingress 访问域名"
  type        = string
  default     = "plantuml.example.com"
}

variable "plantuml_enable_ingress" {
  description = "是否启用 Ingress"
  type        = bool
  default     = false
}
