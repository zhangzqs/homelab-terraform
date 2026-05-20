resource "kubernetes_service_v1" "aria_ng" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.aria_ng_service_name
    namespace = local.namespace
    labels = {
      app = local.aria_ng_app_name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    selector = {
      app = local.aria_ng_app_name
    }
  }
}
