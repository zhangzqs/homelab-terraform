resource "kubernetes_service_v1" "postgres" {
  depends_on = [kubernetes_namespace_v1.this]

  metadata {
    name      = local.postgres_service_name
    namespace = local.namespace
    labels    = { app = local.postgres_name }
  }

  spec {
    type     = "ClusterIP"
    selector = { app = local.postgres_name }

    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
    }
  }
}

resource "kubernetes_service_v1" "redis" {
  depends_on = [kubernetes_namespace_v1.this]

  metadata {
    name      = local.redis_service_name
    namespace = local.namespace
    labels    = { app = local.redis_name }
  }

  spec {
    type     = "ClusterIP"
    selector = { app = local.redis_name }

    port {
      name        = "redis"
      port        = 6379
      target_port = 6379
    }
  }
}

resource "kubernetes_service_v1" "app" {
  depends_on = [kubernetes_namespace_v1.this]

  metadata {
    name      = local.app_service_name
    namespace = local.namespace
    labels    = { app = local.app_name }
  }

  spec {
    type     = "ClusterIP"
    selector = { app = local.app_name }

    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
  }
}
