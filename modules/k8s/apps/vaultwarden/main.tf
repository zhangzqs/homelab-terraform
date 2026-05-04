module "app" {
  source = "../common_simple_app"

  providers = {
    kubernetes = kubernetes
  }

  app_name        = "vaultwarden"
  namespace       = "vaultwarden"
  container_image = "vaultwarden/server:1.35.2"

  container_ports = [
    {
      name           = "http"
      container_port = 80
      protocol       = "TCP"
    }
  ]

  service_ports = [
    {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
  ]

  # 持久化存储配置
  # 方式1：自动创建新的 PVC（默认）
  volume_mounts = [
    {
      name         = "data"
      mount_path   = "/data"
      storage_size = "1Gi"

      # 可以指定 StorageClass，如果不指定则使用默认的
      storage_class = var.pvc_storage_class_name
    }
  ]

  httproute_enabled = true
  httproute_hostnames = [
    var.httproute_hostname
  ]
  httproute_rules = [
    { backendRefs = [{ port = 80 }] }
  ]
  gateway_name      = var.gateway_name
  gateway_namespace = var.gateway_namespace
}
