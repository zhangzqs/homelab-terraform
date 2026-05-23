variable "httproute_hostname" {
  description = "KMS GUI HTTPRoute 访问域名"
  type        = string
}

variable "gateway_name" {
  description = "Gateway 资源名称"
  type        = string
}

variable "gateway_namespace" {
  description = "Gateway 所在命名空间"
  type        = string
}

variable "pvc_storage_class_name" {
  description = "PVC 存储类名称（如 nfs-client）"
  type        = string
  default     = null
}

variable "kms_app_image" {
  description = "KMS 服务镜像"
  type        = string
  default     = "11notes/kms:1.0.3"
}

variable "kms_gui_image" {
  description = "KMS GUI 镜像"
  type        = string
  default     = "11notes/kms-gui:1.0.3"
}

variable "kms_timezone" {
  description = "时区设置"
  type        = string
  default     = "Asia/Shanghai"
}

variable "kms_var_storage_size" {
  description = "KMS 数据存储大小"
  type        = string
  default     = "1Gi"
}
