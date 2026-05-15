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

variable "command_type" {
  description = "命令类型"
  type        = string
  default     = "shell-script"

  validation {
    condition     = contains(["shell", "shell-script"], var.command_type)
    error_message = "command_type 必须是 shell 或 shell-script"
  }
}

variable "command" {
  description = "要执行的命令"
  type        = string
}

variable "timeout" {
  description = "等待执行结果超时时间 (秒)"
  type        = number
  default     = 900
}

variable "poll_interval" {
  description = "轮询间隔 (秒)"
  type        = number
  default     = 3
}
