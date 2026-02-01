output "speedtest_namespace" {
  description = "Speedtest 命名空间名称"
  value       = kubernetes_namespace_v1.speedtest.metadata[0].name
}

output "speedtest_service_name" {
  description = "Speedtest 服务名称"
  value       = kubernetes_service_v1.speedtest.metadata[0].name
}

output "speedtest_service_port" {
  description = "Speedtest 服务端口"
  value       = kubernetes_service_v1.speedtest.spec[0].port[0].port
}

output "speedtest_service_url" {
  description = "Speedtest 服务访问地址 (集群内部)"
  value       = "http://${kubernetes_service_v1.speedtest.metadata[0].name}.${kubernetes_namespace_v1.speedtest.metadata[0].name}.svc.cluster.local:${kubernetes_service_v1.speedtest.spec[0].port[0].port}"
}
