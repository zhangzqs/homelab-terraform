# HTTPRoute 使用 Gateway API 替代 Ingress
resource "kubernetes_manifest" "speedtest_httproute" {
  count = var.speedtest_enable_httproute ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "speedtest-httproute"
      namespace = "speedtest"
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = [var.speedtest_httproute_host]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name = "librespeed"
              port = 80
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_service_v1.speedtest
  ]
}
