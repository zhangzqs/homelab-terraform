resource "kubernetes_deployment_v1" "aria_ng" {
  depends_on = [
    kubernetes_namespace_v1.namespace,
    kubernetes_config_map_v1.aria_ng_proxy,
  ]

  metadata {
    name      = local.aria_ng_deployment_name
    namespace = local.namespace
    labels = {
      app = local.aria_ng_app_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.aria_ng_app_name
      }
    }

    template {
      metadata {
        annotations = {
          "checksum/aria-ng-proxy" = sha256(jsonencode(kubernetes_config_map_v1.aria_ng_proxy.data))
        }

        labels = {
          app = local.aria_ng_app_name
        }
      }

      spec {
        container {
          name              = "aria-ng-proxy"
          image             = var.aria_ng_proxy_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          volume_mount {
            name       = "aria-ng-proxy-config"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
          }

          volume_mount {
            name       = "aria-ng-proxy-config"
            mount_path = "/usr/share/nginx/html/aria-ng-default-rpc.js"
            sub_path   = "aria-ng-default-rpc.js"
          }
        }

        container {
          name              = "aria-ng-static"
          image             = var.aria_ng_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "static"
            container_port = var.aria_ng_upstream_port
            protocol       = "TCP"
          }
        }

        volume {
          name = "aria-ng-proxy-config"

          config_map {
            name = kubernetes_config_map_v1.aria_ng_proxy.metadata[0].name
          }
        }
      }
    }
  }
}
