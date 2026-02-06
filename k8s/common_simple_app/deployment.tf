resource "kubernetes_deployment_v1" "deployment" {
  depends_on = [
    kubernetes_namespace_v1.namespace
  ]

  metadata {
    name      = local.deployment_name
    namespace = local.namespace
    labels = {
      app = local.app_name
    }
  }

  spec {
    replicas = var.pod_replicas

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
          name  = local.container_name
          image = var.container_image

          # 如果本地有，就直接使用本地镜像
          # 如果本地没有，才去镜像仓库拉取
          image_pull_policy = "IfNotPresent"

          dynamic "port" {
            for_each = var.container_ports
            content {
              name           = port.value.name
              container_port = port.value.container_port
              protocol       = port.value.protocol
            }
          }

          dynamic "env" {
            for_each = var.container_env
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            requests = {
              cpu    = var.container_resources.requests.cpu
              memory = var.container_resources.requests.memory
            }
            limits = {
              cpu    = var.container_resources.limits.cpu
              memory = var.container_resources.limits.memory
            }
          }

          dynamic "liveness_probe" {
            for_each = var.liveness_probe.enabled ? [1] : []
            content {
              http_get {
                path = var.liveness_probe.path
                port = var.liveness_probe.port
              }
              initial_delay_seconds = var.liveness_probe.initial_delay_seconds
              period_seconds        = var.liveness_probe.period_seconds
              timeout_seconds       = var.liveness_probe.timeout_seconds
              failure_threshold     = var.liveness_probe.failure_threshold
            }
          }

          dynamic "readiness_probe" {
            for_each = var.readiness_probe.enabled ? [1] : []
            content {
              http_get {
                path = var.readiness_probe.path
                port = var.readiness_probe.port
              }
              initial_delay_seconds = var.readiness_probe.initial_delay_seconds
              period_seconds        = var.readiness_probe.period_seconds
              timeout_seconds       = var.readiness_probe.timeout_seconds
              failure_threshold     = var.readiness_probe.failure_threshold
            }
          }

          dynamic "volume_mount" {
            for_each = var.persistent_volumes
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.mount_path
            }
          }
        }

        dynamic "volume" {
          for_each = var.persistent_volumes
          content {
            name = volume.value.name

            persistent_volume_claim {
              claim_name = "${local.app_name}-${volume.value.name}"
            }
          }
        }
      }
    }
  }
}
