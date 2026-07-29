resource "kubernetes_secret_v1" "credentials" {
  depends_on = [kubernetes_namespace_v1.this]

  metadata {
    name      = "new-api-credentials"
    namespace = local.namespace
  }

  type = "Opaque"

  data = {
    POSTGRES_PASSWORD = var.postgres_password
    REDIS_PASSWORD    = var.redis_password
    SESSION_SECRET    = var.session_secret
    CRYPTO_SECRET     = var.crypto_secret
    SQL_DSN           = "postgresql://root:${urlencode(var.postgres_password)}@${local.postgres_service_name}:5432/new-api"
    REDIS_CONN_STRING = "redis://:${urlencode(var.redis_password)}@${local.redis_service_name}:6379"
  }
}
