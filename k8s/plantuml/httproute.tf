# HTTPRoute 使用 Gateway API 替代 Ingress
resource "kubernetes_manifest" "plantuml_httproute" {
  count = var.plantuml_enable_httproute ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "plantuml-httproute"
      namespace = "plantuml"
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name
          namespace = var.gateway_namespace
        }
      ]
      hostnames = [var.plantuml_httproute_host]
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
              name = "plantuml-server"
              port = 8080
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_service_v1.plantuml
  ]
}
