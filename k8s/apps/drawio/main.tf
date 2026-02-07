module "app" {
  source = "../common_simple_app"

  providers = {
    kubernetes = kubernetes
  }

  app_name        = "drawio"
  namespace       = "drawio"
  container_image = "jgraph/drawio:27.0.5"

  container_ports = [
    {
      name           = "http"
      container_port = 8080
      protocol       = "TCP"
    }
  ]
  liveness_probe = {
    enabled               = true
    path                  = "/"
    port                  = 8080
    initial_delay_seconds = 30
    period_seconds        = 10
    timeout_seconds       = 10
    failure_threshold     = 20
  }

  readiness_probe = {
    enabled               = true
    path                  = "/"
    port                  = 8080
    initial_delay_seconds = 30
    period_seconds        = 10
    timeout_seconds       = 10
    failure_threshold     = 20
  }

  service_ports = [
    {
      name        = "http"
      port        = 80
      target_port = 8080
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
