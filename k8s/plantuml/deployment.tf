resource "kubernetes_deployment_v1" "plantuml" {
  metadata {
    name      = "plantuml-server"
    namespace = kubernetes_namespace_v1.plantuml.metadata[0].name
    labels = {
      app = "plantuml-server"
    }
  }

  spec {
    replicas = var.plantuml_replicas

    selector {
      match_labels = {
        app = "plantuml-server"
      }
    }

    template {
      metadata {
        labels = {
          app = "plantuml-server"
        }
      }

      spec {
        container {
          name  = "plantuml"
          image = var.plantuml_image

          port {
            name           = "http"
            container_port = 8080
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = var.plantuml_cpu_request
              memory = var.plantuml_memory_request
            }
            limits = {
              cpu    = var.plantuml_cpu_limit
              memory = var.plantuml_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 10
            failure_threshold     = 20
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 10
            failure_threshold     = 20
          }
        }
      }
    }
  }
}
