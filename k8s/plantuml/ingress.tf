resource "kubernetes_ingress_v1" "plantuml" {
  count = var.plantuml_enable_ingress ? 1 : 0

  metadata {
    name      = "plantuml-ingress"
    namespace = "plantuml"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "false"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = var.plantuml_ingress_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "plantuml-server"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_service_v1.plantuml
  ]
}
