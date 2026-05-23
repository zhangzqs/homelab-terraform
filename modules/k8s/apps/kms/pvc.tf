resource "kubernetes_persistent_volume_claim_v1" "kms_var" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.kms_var_pvc_name
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.pvc_storage_class_name

    resources {
      requests = {
        storage = var.kms_var_storage_size
      }
    }
  }
}
