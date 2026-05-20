resource "kubernetes_deployment_v1" "aria2" {
  depends_on = [
    kubernetes_namespace_v1.namespace,
    kubernetes_persistent_volume_claim_v1.aria2_config,
    kubernetes_persistent_volume_claim_v1.aria2_downloads,
    kubernetes_config_map_v1.aria2_config,
  ]

  metadata {
    name      = local.aria2_deployment_name
    namespace = local.namespace
    labels = {
      app = local.aria2_app_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.aria2_app_name
      }
    }

    template {
      metadata {
        annotations = {
          "checksum/aria2-config" = sha256(jsonencode(kubernetes_config_map_v1.aria2_config.data))
        }

        labels = {
          app = local.aria2_app_name
        }
      }

      spec {
        dns_policy = "None"

        dns_config {
          nameservers = ["10.43.0.10"]
          searches = [
            "${local.namespace}.svc.cluster.local",
            "svc.cluster.local",
            "cluster.local",
          ]

          option {
            name  = "ndots"
            value = "1"
          }
        }

        container {
          name              = "aria2"
          image             = var.aria2_image
          image_pull_policy = "IfNotPresent"

          env {
            name  = "TZ"
            value = var.aria2_timezone
          }

          port {
            name           = "rpc"
            container_port = 6800
            protocol       = "TCP"
          }

          port {
            name           = "bt-listen"
            container_port = 6888
            protocol       = "TCP"
          }

          port {
            name           = "bt-dht"
            container_port = 6888
            protocol       = "UDP"
          }

          volume_mount {
            name       = "aria2-config-pvc"
            mount_path = "/conf"
          }

          volume_mount {
            name       = "aria2-downloads-pvc"
            mount_path = "/data"
          }

          volume_mount {
            name       = "aria2-runtime-config"
            mount_path = "/conf/aria2.conf"
            sub_path   = "aria2.conf"
          }
        }

        volume {
          name = "aria2-config-pvc"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.aria2_config.metadata[0].name
          }
        }

        volume {
          name = "aria2-downloads-pvc"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.aria2_downloads.metadata[0].name
          }
        }

        volume {
          name = "aria2-runtime-config"

          config_map {
            name = kubernetes_config_map_v1.aria2_config.metadata[0].name
          }
        }
      }
    }
  }
}
