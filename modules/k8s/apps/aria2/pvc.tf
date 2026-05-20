resource "kubernetes_persistent_volume_claim_v1" "aria2_config" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.aria2_config_pvc_name
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.pvc_storage_class_name

    resources {
      requests = {
        storage = var.aria2_config_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "aria2_downloads" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.aria2_downloads_pvc_name
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.pvc_storage_class_name

    resources {
      requests = {
        storage = var.aria2_downloads_storage_size
      }
    }
  }
}
