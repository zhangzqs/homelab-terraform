
module "gateway_api" {
  source = "../gateway-api"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

module "speedtest" {
  source = "../speedtest"

  speedtest_enable_httproute = true
  gateway_name               = module.gateway_api.gateway_name
  gateway_namespace          = module.gateway_api.gateway_api_namespace

  providers = {
    kubernetes = kubernetes
  }
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
