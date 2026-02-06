module "vaultwarden" {
  source = "../common_simple_app"

  providers = {
    kubernetes = kubernetes
  }

  app_name        = 
  namespace       = "vaultwarden"
  container_image = "vaultwarden/server:1.35.2"

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

  persistent_volumes = [
    {
      name         = "data"
      mount_path   = "/data"
      storage_size = "5Gi"
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
