resource "kubernetes_service_v1" "svc" {
  count = length(var.service_ports) > 0 ? 1 : 0

  depends_on = [
    kubernetes_namespace_v1.namespace
  ]

  metadata {
    name      = local.svc_name
    namespace = local.namespace
    labels = {
      app = local.app_name
    }
  }

  spec {
    // 给所有这个服务对应的所有Pod分配一个固定的虚拟IP地址，
    // 集群内的其他Pod可以通过这个IP地址访问这个服务，
    // 底层自动负载均衡到这个服务对应的所有Pod上。
    type = "ClusterIP"

    selector = {
      app = local.app_name
    }

    dynamic "port" {
      for_each = var.service_ports
      content {
        name        = port.value.name        // 端口名称
        port        = port.value.port        // svc 对外端口
        target_port = port.value.target_port // Pod 容器端口
        protocol    = port.value.protocol    // 协议类型，默认为 TCP
      }
    }
  }
}
