resource "kubernetes_service_v1" "kms_app" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.kms_app_service
    namespace = local.namespace
    labels = {
      app = local.kms_app_name
    }
  }

  spec {
    type = "LoadBalancer"

    port {
      name        = "kms"
      port        = 1688
      target_port = 1688
      protocol    = "TCP"
    }

    selector = {
      app = local.kms_app_name
    }
  }
}
