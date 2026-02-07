module "gateway" {
  source = "../gateway"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

module "nfs_csi" {
  source = "../nfs_csi"
  providers = {
    helm = helm
  }
}

module "nfs_storage_class" {
  source = "../nfs_storage_class"
  providers = {
    kubernetes = kubernetes
  }
  depends_on = [module.nfs_csi]

  nfs_server     = var.nfs_server
  nfs_share_path = var.nfs_share_path
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

  httproute_hostname     = "vaultwarden.${var.httproute_base_hostname}"
  gateway_name           = module.gateway.gateway_name
  gateway_namespace      = module.gateway.gateway_namespace
  pvc_storage_class_name = module.nfs_storage_class.storage_class_name
}
