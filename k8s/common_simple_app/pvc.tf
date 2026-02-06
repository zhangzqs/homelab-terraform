resource "kubernetes_persistent_volume_claim_v1" "pvc" {
  for_each = { for pv in var.persistent_volumes : pv.name => pv }

  depends_on = [
    kubernetes_namespace_v1.namespace
  ]

  metadata {
    name      = "${local.app_name}-${each.value.name}"
    namespace = local.namespace
    labels = {
      app = local.app_name
    }
  }

  spec {
    access_modes = each.value.access_modes

    resources {
      requests = {
        storage = each.value.storage_size
      }
    }

    storage_class_name = each.value.storage_class
  }
}
