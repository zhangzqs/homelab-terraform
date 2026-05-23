resource "kubernetes_deployment_v1" "kms_gui" {
  depends_on = [
    kubernetes_namespace_v1.namespace,
    kubernetes_persistent_volume_claim_v1.kms_var,
  ]

  metadata {
    name      = local.kms_gui_deployment
    namespace = local.namespace
    labels = {
      app = local.kms_gui_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.kms_gui_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.kms_gui_name
        }
      }

      spec {
        container {
          name              = "kms-gui"
          image             = var.kms_gui_image
          image_pull_policy = "IfNotPresent"

          env {
            name  = "TZ"
            value = var.kms_timezone
          }

          port {
            name           = "http"
            container_port = 3000
            protocol       = "TCP"
          }

          volume_mount {
            name       = local.kms_var_pvc_name
            mount_path = "/kms/var"
          }
        }

        volume {
          name = local.kms_var_pvc_name

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.kms_var.metadata[0].name
          }
        }
      }
    }
  }
}
