variable "httproute_hostname" {
  description = "HTTPRoute 访问域名"
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
  description = "PVC 使用的 StorageClass 名称（可选，为空时使用默认 StorageClass）"
  type        = string

  // 不能为空字符串
  validation {
    condition     = var.pvc_storage_class_name == "" || length(var.pvc_storage_class_name) > 0
    error_message = "PVC 使用的 StorageClass 名称不能为空字符串"
  }
}
