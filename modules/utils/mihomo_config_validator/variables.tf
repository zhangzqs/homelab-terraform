variable "config_content" {
  description = "待校验的 Mihomo YAML 配置内容"
  type        = string
}

variable "mihomo_image" {
  description = "用于校验的 Mihomo Docker 镜像，应与部署端内核版本保持一致"
  type        = string
  default     = "metacubex/mihomo:v1.19.28"
}
