output "vm_namespace" {
  description = "VictoriaMetrics 监控系统命名空间"
  value       = helm_release.victoria_metrics_operator.namespace
}

output "operator_status" {
  description = "VictoriaMetrics Operator 部署状态"
  value       = helm_release.victoria_metrics_operator.status
}

output "k8s_stack_status" {
  description = "VictoriaMetrics K8s Stack 部署状态"
  value       = helm_release.victoria_metrics_k8s_stack.status
}

output "grafana_url" {
  description = "Grafana 访问地址 (NodePort)"
  value       = var.grafana_service_type == "NodePort" ? "http://<node-ip>:${var.grafana_nodeport}" : "Service type: ${var.grafana_service_type}"
}

output "grafana_admin_user" {
  description = "Grafana 管理员用户名"
  value       = "admin"
}

output "vmsingle_url" {
  description = "VMSingle 内部访问地址"
  value       = "http://vmsingle-victoria-metrics-k8s-stack.${var.vm_namespace}.svc:8429"
}

output "vmalert_url" {
  description = "VMAlert 内部访问地址"
  value       = var.vmalert_enabled ? "http://vmalert-victoria-metrics-k8s-stack.${var.vm_namespace}.svc:8080" : "VMAlert is disabled"
}

output "alertmanager_url" {
  description = "AlertManager 内部访问地址"
  value       = var.alertmanager_enabled ? "http://vmalertmanager-victoria-metrics-k8s-stack.${var.vm_namespace}.svc:9093" : "AlertManager is disabled"
}
