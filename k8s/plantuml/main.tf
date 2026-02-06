module "plantuml" {
  source = "../common_simple_app"

  providers = {
    kubernetes = kubernetes
  }

  app_name        = "plantuml"
  namespace       = "plantuml"
  container_image = "plantuml/plantuml-server:jetty-v1.2025.2"

  container_ports = [
    {
      name           = "http"
      container_port = 8080
      protocol       = "TCP"
    }
  ]

  service_ports = [
    {
      name        = "http"
      port        = 80   // svc 对外端口
      target_port = 8080 // Pod 容器端口
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
}
