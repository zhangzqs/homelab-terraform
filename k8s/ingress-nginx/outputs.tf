output "ingress_nginx_namespace" {
  description = "Ingress Nginx 命名空间"
  value       = helm_release.ingress_nginx.namespace
}

output "ingress_nginx_status" {
  description = "Ingress Nginx 部署状态"
  value       = helm_release.ingress_nginx.status
}

output "ingress_nginx_version" {
  description = "Ingress Nginx Chart 版本"
  value       = helm_release.ingress_nginx.version
}

output "ingress_nginx_http_nodeport" {
  description = "Ingress Nginx HTTP NodePort"
  value       = var.ingress_nginx_http_nodeport
}

output "ingress_nginx_https_nodeport" {
  description = "Ingress Nginx HTTPS NodePort"
  value       = var.ingress_nginx_https_nodeport
}
