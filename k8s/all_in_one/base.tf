module "gateway" {
  source = "../base/gateway"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

module "nfs_csi" {
  source = "../base/nfs_csi"
  providers = {
    helm = helm
  }
}

module "nfs_storage_class" {
  source = "../base/nfs_storage_class"
  providers = {
    kubernetes = kubernetes
  }
  depends_on = [module.nfs_csi]

  nfs_server     = var.nfs_server
  nfs_share_path = var.nfs_share_path
}