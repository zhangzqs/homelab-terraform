resource "kubernetes_manifest" "kms_gui_httproute" {
  depends_on = [
    kubernetes_service_v1.kms_gui,
    kubernetes_namespace_v1.namespace,
  ]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "kms-gui-route"
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
              name = local.kms_gui_service
              port = 80
            }
          ]
        }
      ]
    }
  }
}
