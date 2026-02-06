module "gateway" {
  source = "../gateway"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

module "speedtest" {
  source = "../speedtest"

  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "speedtest.example.com"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}

module "plantuml" {
  source = "../plantuml"
  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "plantuml.example.com"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}
