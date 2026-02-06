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

  httproute_hostname = "speedtest.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}

module "plantuml" {
  source = "../plantuml"
  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "plantuml.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}

module "vaultwarden" {
  source = "../vaultwarden"

  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "vaultwarden.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}
