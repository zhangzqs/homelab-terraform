resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  depends_on = [kubernetes_namespace_v1.this]

  metadata {
    name      = "postgres-data"
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = var.postgres_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim_v1" "app" {
  for_each = {
    data = var.data_storage_size
    logs = var.logs_storage_size
  }

  depends_on = [kubernetes_namespace_v1.this]

  metadata {
    name      = "new-api-${each.key}"
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = each.value
      }
    }
  }
}
