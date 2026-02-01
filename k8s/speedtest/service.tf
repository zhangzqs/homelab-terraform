resource "kubernetes_service" "speedtest" {
  metadata {
    name      = "librespeed"
    namespace = kubernetes_namespace.speedtest.metadata[0].name
    labels = {
      app = "librespeed"
    }
  }

  spec {
    type = var.speedtest_service_type

    selector = {
      app = "librespeed"
    }

    port {
      name        = "http"
      port        = var.speedtest_service_port
      target_port = 80
      protocol    = "TCP"
    }
  }
}
