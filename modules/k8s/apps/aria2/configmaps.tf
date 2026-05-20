resource "kubernetes_config_map_v1" "aria2_config" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = "aria2-config"
    namespace = local.namespace
  }

  data = {
    "aria2.conf" = templatefile("${path.module}/templates/aria2.conf.tftpl", {
      aria2_disk_cache = var.aria2_disk_cache
      aria2_rpc_secret = var.aria2_rpc_secret
    })
  }
}

resource "kubernetes_config_map_v1" "aria_ng_proxy" {
  depends_on = [kubernetes_namespace_v1.namespace]

  metadata {
    name      = "aria-ng-proxy"
    namespace = local.namespace
  }

  data = {
    "default.conf" = templatefile("${path.module}/templates/aria-ng-proxy.conf.tftpl", {
      aria_ng_upstream_port = var.aria_ng_upstream_port
    })
    "aria-ng-default-rpc.js" = templatefile("${path.module}/templates/aria-ng-default-rpc.js.tftpl", {
      aria2_rpc_secret_base64 = base64encode(var.aria2_rpc_secret)
    })
  }
}
