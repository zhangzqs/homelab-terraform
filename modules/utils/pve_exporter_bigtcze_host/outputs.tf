output "listen_address" {
  value       = var.listen_address
  description = "Exporter listen address"
}

output "listen_port" {
  value       = var.listen_port
  description = "Exporter listen port"
}

output "metrics_url" {
  value       = "http://${var.listen_address}:${var.listen_port}/metrics"
  description = "Metrics endpoint URL"
}
