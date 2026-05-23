resource "kubernetes_service_v1" "kms_gui" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.kms_gui_service
    namespace = local.namespace
    labels = {
      app = local.kms_gui_name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      target_port = 3000
      protocol    = "TCP"
    }

    selector = {
      app = local.kms_gui_name
    }
  }
}
