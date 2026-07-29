resource "kubernetes_deployment_v1" "app" {
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.credentials,
    kubernetes_persistent_volume_claim_v1.app,
  ]

  metadata {
    name      = local.app_name
    namespace = local.namespace
    labels    = { app = local.app_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = local.app_name }
    }

    template {
      metadata {
        labels = { app = local.app_name }
      }

      spec {
        dns_config {
          option {
            name  = "ndots"
            value = "1"
          }
        }

        container {
          name  = local.app_name
          image = "calciumion/new-api:v1.0.0-rc.22"
          args  = ["--log-dir", "/app/logs"]

          dynamic "env" {
            for_each = toset(["SQL_DSN", "REDIS_CONN_STRING", "SESSION_SECRET", "CRYPTO_SECRET"])
            content {
              name = env.value
              value_from {
                secret_key_ref {
                  name = kubernetes_secret_v1.credentials.metadata[0].name
                  key  = env.value
                }
              }
            }
          }

          env {
            name  = "TZ"
            value = "Asia/Shanghai"
          }
          env {
            name  = "ERROR_LOG_ENABLED"
            value = "true"
          }
          env {
            name  = "BATCH_UPDATE_ENABLED"
            value = "true"
          }
          env {
            name  = "NODE_NAME"
            value = "new-api-node-1"
          }

          port {
            name           = "http"
            container_port = 3000
          }

          liveness_probe {
            http_get {
              path = "/api/status"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/api/status"
              port = 3000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }
          volume_mount {
            name       = "logs"
            mount_path = "/app/logs"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.app["data"].metadata[0].name
          }
        }
        volume {
          name = "logs"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.app["logs"].metadata[0].name
          }
        }
      }
    }
  }
}
