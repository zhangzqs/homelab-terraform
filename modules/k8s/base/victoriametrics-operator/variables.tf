variable "vm_namespace" {
  description = "VictoriaMetrics 监控系统命名空间"
  type        = string
  default     = "victoriametrics"
}

variable "vm_storage_class" {
  description = "存储类名称"
  type        = string
  default     = "local-path"
}

variable "vm_retention_period" {
  description = "数据保留时间"
  type        = string
  default     = "14d"
}

variable "vmsingle_storage_size" {
  description = "VMSingle 存储大小"
  type        = string
  default     = "20Gi"
}

variable "grafana_storage_enabled" {
  description = "是否为 Grafana 启用持久化存储"
  type        = bool
  default     = true
}

variable "grafana_storage_size" {
  description = "Grafana 持久化存储大小"
  type        = string
  default     = "5Gi"
}

variable "alertmanager_storage_enabled" {
  description = "是否为 AlertManager 启用持久化存储"
  type        = bool
  default     = true
}

variable "alertmanager_storage_size" {
  description = "AlertManager 持久化存储大小"
  type        = string
  default     = "2Gi"
}

variable "grafana_admin_password" {
  description = "Grafana 管理员密码"
  type        = string
  sensitive   = true
  default     = "admin"
}

variable "grafana_service_type" {
  description = "Grafana Service 类型 (NodePort, LoadBalancer, ClusterIP)"
  type        = string
  default     = "NodePort"
}

variable "grafana_nodeport" {
  description = "Grafana NodePort 端口号"
  type        = number
  default     = 30300
}

variable "vmalert_enabled" {
  description = "是否启用 VMAlert"
  type        = bool
  default     = true
}

variable "alertmanager_enabled" {
  description = "是否启用 AlertManager"
  type        = bool
  default     = true
}

variable "prometheus_node_exporter_enabled" {
  description = "是否启用 Node Exporter"
  type        = bool
  default     = true
}

variable "kube_state_metrics_enabled" {
  description = "是否启用 Kube State Metrics"
  type        = bool
  default     = true
}
