resource "kubernetes_deployment" "speedtest" {
  metadata {
    name      = "librespeed"
    namespace = kubernetes_namespace.speedtest.metadata[0].name
    labels = {
      app = "librespeed"
    }
  }

  spec {
    replicas = var.speedtest_replicas

    selector {
      match_labels = {
        app = "librespeed"
      }
    }

    template {
      metadata {
        labels = {
          app = "librespeed"
        }
      }

      spec {
        container {
          name  = "speedtest"
          image = var.speedtest_image

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          env {
            name  = "MODE"
            value = var.speedtest_mode
          }

          env {
            name  = "TELEMETRY"
            value = var.speedtest_telemetry
          }

          env {
            name  = "PASSWORD"
            value = var.speedtest_password
          }

          env {
            name  = "EMAIL"
            value = var.speedtest_email
          }

          resources {
            requests = {
              cpu    = var.speedtest_cpu_request
              memory = var.speedtest_memory_request
            }
            limits = {
              cpu    = var.speedtest_cpu_limit
              memory = var.speedtest_memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }
        }
      }
    }
  }
}
