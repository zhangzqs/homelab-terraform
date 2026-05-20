resource "kubernetes_manifest" "aria_ng_httproute" {
  depends_on = [
    kubernetes_service_v1.aria2,
    kubernetes_service_v1.aria_ng,
    kubernetes_namespace_v1.namespace,
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
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/jsonrpc"
              }
            },
            {
              path = {
                type  = "PathPrefix"
                value = "/rpc"
              }
            }
          ]
          backendRefs = [
            {
              name = local.aria2_service_name
              port = 6800
            }
          ]
        },
        {
          backendRefs = [
            {
              name = local.aria_ng_service_name
              port = 80
            }
          ]
        }
      ]
    }
  }
}
