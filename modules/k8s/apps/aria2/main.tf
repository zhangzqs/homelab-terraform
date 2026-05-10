locals {
  namespace           = "aria2"
  app_name            = "aria2"
  aria_ng_name        = "aria-ng"
  aria2_deployment    = "aria2"
  aria_ng_deployment  = "aria-ng"
  aria2_service       = "aria2-service"
  aria_ng_service     = "aria-ng-service"
  config_volume       = "aria2-config"
  downloads_volume    = "aria2-downloads"
  config_pvc          = "aria2-config-pvc"
  downloads_pvc       = "aria2-downloads-pvc"
}

# Namespace
resource "kubernetes_namespace_v1" "namespace" {
  metadata {
    name = local.namespace
  }
}

# ConfigMap for aria2 configuration
resource "kubernetes_config_map_v1" "aria2_config" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = "aria2-config"
    namespace = local.namespace
  }

  data = {
    UMASK_SET      = "022"
    RPC_SECRET     = var.aria2_rpc_secret
    RPC_PORT       = "6800"
    LISTEN_PORT    = "6888"
    DISK_CACHE     = var.aria2_disk_cache
    IPV6_MODE      = "false"
    UPDATE_TRACKERS = "true"
    TZ             = var.aria2_timezone
  }
}

# PVC for aria2 config
resource "kubernetes_persistent_volume_claim_v1" "aria2_config" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.config_pvc
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.pvc_storage_class_name
    resources {
      requests = {
        storage = var.aria2_config_storage_size
      }
    }
  }
}

# PVC for aria2 downloads
resource "kubernetes_persistent_volume_claim_v1" "aria2_downloads" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.downloads_pvc
    namespace = local.namespace
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.pvc_storage_class_name
    resources {
      requests = {
        storage = var.aria2_downloads_storage_size
      }
    }
  }
}

# Deployment for aria2
resource "kubernetes_deployment_v1" "aria2" {
  depends_on = [
    kubernetes_namespace_v1.namespace,
    kubernetes_persistent_volume_claim_v1.aria2_config,
    kubernetes_persistent_volume_claim_v1.aria2_downloads,
    kubernetes_config_map_v1.aria2_config
  ]

  metadata {
    name      = local.aria2_deployment
    namespace = local.namespace
    labels = {
      app = local.app_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.app_name
        }
      }

      spec {
        container {
          name  = "aria2"
          image = var.aria2_image

          image_pull_policy = "IfNotPresent"

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

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.aria2_config.metadata[0].name
            }
          }

          volume_mount {
            name       = local.config_volume
            mount_path = "/config"
          }

          volume_mount {
            name       = local.downloads_volume
            mount_path = "/downloads"
          }
        }

        volume {
          name = local.config_volume
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.aria2_config.metadata[0].name
          }
        }

        volume {
          name = local.downloads_volume
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.aria2_downloads.metadata[0].name
          }
        }
      }
    }
  }
}

# Service for aria2 RPC
resource "kubernetes_service_v1" "aria2" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.aria2_service
    namespace = local.namespace
    labels = {
      app = local.app_name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name       = "rpc"
      port       = 6800
      target_port = 6800
      protocol   = "TCP"
    }

    port {
      name       = "bt-listen"
      port       = 6888
      target_port = 6888
      protocol   = "TCP"
    }

    port {
      name       = "bt-dht"
      port       = 6888
      target_port = 6888
      protocol   = "UDP"
    }

    selector = {
      app = local.app_name
    }
  }
}

# Deployment for aria-ng
resource "kubernetes_deployment_v1" "aria_ng" {
  depends_on = [
    kubernetes_namespace_v1.namespace,
    kubernetes_deployment_v1.aria2
  ]

  metadata {
    name      = local.aria_ng_deployment
    namespace = local.namespace
    labels = {
      app = local.aria_ng_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.aria_ng_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.aria_ng_name
        }
      }

      spec {
        container {
          name  = "aria-ng"
          image = var.aria_ng_image

          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
            protocol       = "TCP"
          }

          env {
            name  = "ARIA2_RPC_URL"
            value = "http://${local.aria2_service}:6800/jsonrpc"
          }
        }
      }
    }
  }
}

# Service for aria-ng web UI
resource "kubernetes_service_v1" "aria_ng" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.aria_ng_service
    namespace = local.namespace
    labels = {
      app = local.aria_ng_name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    selector = {
      app = local.aria_ng_name
    }
  }
}

# HTTPRoute for aria-ng web UI
resource "kubernetes_manifest" "aria_ng_httproute" {
  depends_on = [
    kubernetes_service_v1.aria_ng,
    kubernetes_namespace_v1.namespace
  ]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "aria-ng-route"
      namespace = local.namespace
    }

    spec = {
      hostnames = [var.httproute_hostname]

      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]

      rules = [
        {
          backendRefs = [
            {
              name = local.aria_ng_service
              port = 80
            }
          ]
        }
      ]
    }
  }
}
