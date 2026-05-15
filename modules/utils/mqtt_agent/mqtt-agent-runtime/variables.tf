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

variable "poll_interval" {
  description = "Agent 主循环轮询/重连间隔"
  type        = number
  default     = 3
}

variable "replay_window_seconds" {
  description = "反重放时间窗（秒）。需大于 agent 最长启动时间，避免 retained 命令因时间窗过期被拒绝"
  type        = number
  default     = 3600
}

variable "ledger_path" {
  description = "任务幂等落盘路径"
  type        = string
  default     = "/var/lib/mqtt-agent/tasks.jsonl"
}

variable "max_workers" {
  description = "并发执行任务数"
  type        = number
  default     = 4
}

variable "python_executable" {
  description = "Python 解释器路径"
  type        = string
  default     = "/usr/bin/python3"
}
