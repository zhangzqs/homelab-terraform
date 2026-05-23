resource "kubernetes_deployment_v1" "kms_app" {
  depends_on = [
    kubernetes_namespace_v1.namespace,
    kubernetes_persistent_volume_claim_v1.kms_var,
  ]

  metadata {
    name      = local.kms_app_deployment
    namespace = local.namespace
    labels = {
      app = local.kms_app_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.kms_app_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.kms_app_name
        }
      }

      spec {
        init_container {
          name              = "fix-permissions"
          image             = "busybox:1.36"
          command           = ["sh", "-c", "chown -R 1000:1000 /kms/var"]

          volume_mount {
            name       = local.kms_var_pvc_name
            mount_path = "/kms/var"
          }
        }

        container {
          name              = "kms-app"
          image             = var.kms_app_image
          image_pull_policy = "IfNotPresent"

          env {
            name  = "TZ"
            value = var.kms_timezone
          }

          port {
            name           = "kms"
            container_port = 1688
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
