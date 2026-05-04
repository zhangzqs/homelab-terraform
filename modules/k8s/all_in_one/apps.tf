module "speedtest" {
  source = "../apps/speedtest"

  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "speedtest.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}

module "plantuml" {
  source = "../apps/plantuml"
  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "plantuml.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}

module "vaultwarden" {
  count  = 1
  source = "../apps/vaultwarden"

  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname     = "vaultwarden.${var.httproute_base_hostname}"
  gateway_name           = module.gateway.gateway_name
  gateway_namespace      = module.gateway.gateway_namespace
  pvc_storage_class_name = module.nfs_storage_class.storage_class_name
}

module "it_tools" {
  source = "../apps/it_tools"

  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "it-tools.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}

module "drawio" {
  source = "../apps/drawio"

  providers = {
    kubernetes = kubernetes
  }

  httproute_hostname = "drawio.${var.httproute_base_hostname}"
  gateway_name       = module.gateway.gateway_name
  gateway_namespace  = module.gateway.gateway_namespace
}
