resource "kubernetes_manifest" "httproute" {
  depends_on = [
    kubernetes_namespace_v1.this,
    kubernetes_service_v1.app,
  ]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = local.app_service_name
      namespace = local.namespace
    }

    spec = {
      hostnames = [var.httproute_hostname]

      parentRefs = [{
        name      = var.gateway_name
        namespace = var.gateway_namespace
      }]

      rules = [{
        backendRefs = [{
          name = local.app_service_name
          port = 3000
        }]
      }]
    }
  }
}
