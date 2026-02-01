resource "kubernetes_service" "plantuml" {
  metadata {
    name      = "plantuml-server"
    namespace = kubernetes_namespace.plantuml.metadata[0].name
    labels = {
      app = "plantuml-server"
    }
  }

  spec {
    type = var.plantuml_service_type

    selector = {
      app = "plantuml-server"
    }

    port {
      name        = "http"
      port        = var.plantuml_service_port
      target_port = 8080
      protocol    = "TCP"
    }
  }
}
