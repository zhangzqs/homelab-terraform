output "plantuml_namespace" {
  description = "PlantUML 命名空间名称"
  value       = kubernetes_namespace_v1.plantuml.metadata[0].name
}

output "plantuml_service_name" {
  description = "PlantUML 服务名称"
  value       = kubernetes_service_v1.plantuml.metadata[0].name
}

output "plantuml_service_port" {
  description = "PlantUML 服务端口"
  value       = kubernetes_service_v1.plantuml.spec[0].port[0].port
}

output "plantuml_service_url" {
  description = "PlantUML 服务访问地址 (集群内部)"
  value       = "http://${kubernetes_service_v1.plantuml.metadata[0].name}.${kubernetes_namespace_v1.plantuml.metadata[0].name}.svc.cluster.local:${kubernetes_service_v1.plantuml.spec[0].port[0].port}"
}
