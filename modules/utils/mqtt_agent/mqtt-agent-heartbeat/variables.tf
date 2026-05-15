variable "mqtt_config" {
  description = "MQTT broker 配置"
  type = object({
    broker_host  = string
    broker_port  = number
    topic_prefix = string
  })
}

variable "crypto_bundle" {
  description = "加密材料包（node_id + 4 个证书字段）"
  type = object({
    node_id                   = string
    agent_certificate_pem     = string
    agent_private_key_pem     = string
    terraform_certificate_pem = string
    terraform_private_key_pem = string
  })
  sensitive = true
}

variable "instance_id" {
  description = "计算实例 ID（用于控制心跳等待触发）"
  type        = string
}

variable "timeout" {
  description = "等待心跳超时时间 (秒)"
  type        = number
  default     = 900
}

variable "poll_interval" {
  description = "轮询间隔 (秒)"
  type        = number
  default     = 3
}
