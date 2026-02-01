resource "kubernetes_ingress_v1" "speedtest" {
  count = var.speedtest_enable_ingress ? 1 : 0

  metadata {
    name      = "speedtest-ingress"
    namespace = "speedtest"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.speedtest_ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "librespeed"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.speedtest
  ]
}
