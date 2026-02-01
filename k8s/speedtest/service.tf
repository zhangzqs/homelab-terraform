resource "kubernetes_service_v1" "speedtest" {
  metadata {
    name      = "librespeed"
    namespace = kubernetes_namespace_v1.speedtest.metadata[0].name
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
