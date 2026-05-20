resource "kubernetes_service_v1" "aria2" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = local.aria2_service_name
    namespace = local.namespace
    labels = {
      app = local.aria2_app_name
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "rpc"
      port        = 6800
      target_port = 6800
      protocol    = "TCP"
    }

    port {
      name        = "bt-listen"
      port        = 6888
      target_port = 6888
      protocol    = "TCP"
    }

    port {
      name        = "bt-dht"
      port        = 6888
      target_port = 6888
      protocol    = "UDP"
    }

    selector = {
      app = local.aria2_app_name
    }
  }
}
