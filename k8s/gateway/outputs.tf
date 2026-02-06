output "gateway_namespace" {
  description = "Gateway API 命名空间"
  value       = helm_release.nginx_gateway_fabric.namespace
}

output "gateway_status" {
  description = "NGINX Gateway Fabric 部署状态"
  value       = helm_release.nginx_gateway_fabric.status
}
output "gateway_name" {
  description = "Gateway 资源名称"
  value       = var.gateway_name
}

output "gateway_http_nodeport" {
  description = "Gateway HTTP NodePort"
  value       = var.gateway_http_nodeport
}

output "gateway_https_nodeport" {
  description = "Gateway HTTPS NodePort"
  value       = var.gateway_https_nodeport
}
