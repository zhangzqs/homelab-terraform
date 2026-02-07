module "app" {
  source = "../common_simple_app"

  providers = {
    kubernetes = kubernetes
  }

  app_name        = "it-tools"
  namespace       = "it-tools"
  container_image = "corentinth/it-tools:2024.10.22-7ca5933"

  container_ports = [
    {
      name           = "http"
      container_port = 80
      protocol       = "TCP"
    }
  ]

  service_ports = [
    {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  ]

  httproute_enabled = true
  httproute_hostnames = [
    var.httproute_hostname
  ]
  httproute_rules = [
    { backendRefs = [{ port = 80 }] }
  ]
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}
