module "gateway_api" {
  source = "../gateway_api"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

module "speedtest" {
  source = "../common_simple_app"

  providers = {
    kubernetes = kubernetes
  }

  app_name        = "speedtest"
  namespace       = "speedtest"
  container_image = "ghcr.io/librespeed/speedtest:5.4.1"

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
}

module "plantuml" {
  source = "../plantuml"

  plantuml_enable_httproute = true
  gateway_name              = module.gateway_api.gateway_name
  gateway_namespace         = module.gateway_api.gateway_api_namespace

  providers = {
    kubernetes = kubernetes
  }
}
