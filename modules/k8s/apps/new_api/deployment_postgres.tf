resource "kubernetes_deployment_v1" "postgres" {
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.credentials,
    kubernetes_persistent_volume_claim_v1.postgres,
  ]

  metadata {
    name      = local.postgres_name
    namespace = local.namespace
    labels    = { app = local.postgres_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = local.postgres_name }
    }

    template {
      metadata {
        labels = { app = local.postgres_name }
      }

      spec {
        container {
          name  = local.postgres_name
          image = "postgres:15"

          env {
            name  = "POSTGRES_USER"
            value = "root"
          }
          env {
            name  = "POSTGRES_DB"
            value = "new-api"
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.credentials.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          port {
            name           = "postgres"
            container_port = 5432
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.postgres.metadata[0].name
          }
        }
      }
    }
  }
}
