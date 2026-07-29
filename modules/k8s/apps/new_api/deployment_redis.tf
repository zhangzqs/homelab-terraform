resource "kubernetes_deployment_v1" "redis" {
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_secret_v1.credentials,
  ]

  metadata {
    name      = local.redis_name
    namespace = local.namespace
    labels    = { app = local.redis_name }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = local.redis_name }
    }

    template {
      metadata {
        labels = { app = local.redis_name }
      }

      spec {
        container {
          name    = local.redis_name
          image   = "redis:7.4"
          command = ["sh", "-c"]
          args    = ["exec redis-server --requirepass \"$REDIS_PASSWORD\""]

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.credentials.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }

          port {
            name           = "redis"
            container_port = 6379
          }
        }
      }
    }
  }
}
