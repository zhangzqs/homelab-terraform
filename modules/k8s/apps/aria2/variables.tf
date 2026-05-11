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
  description = "PVC 存储类名称（如 nfs-client）"
  type        = string
  default     = null
}

variable "aria2_image" {
  description = "aria2 Docker 镜像"
  type        = string
  default     = "xujinkai/aria2-with-webui:latest"
}

variable "aria_ng_image" {
  description = "aria-ng Docker 镜像"
  type        = string
  default     = "wahyd4/aria2-ui:latest"
}

variable "aria2_config_storage_size" {
  description = "aria2 配置存储大小"
  type        = string
  default     = "5Gi"
}

variable "aria2_downloads_storage_size" {
  description = "aria2 下载存储大小"
  type        = string
  default     = "100Gi"
}

variable "aria2_rpc_secret" {
  description = "aria2 RPC 密钥"
  type        = string
  sensitive   = true
}

variable "aria2_disk_cache" {
  description = "aria2 磁盘缓存大小（如 64M）"
  type        = string
  default     = "64M"
}

variable "aria2_timezone" {
  description = "时区设置"
  type        = string
  default     = "Asia/Shanghai"
}
