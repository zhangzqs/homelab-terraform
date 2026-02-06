# HTTPRoute 使用 Gateway API 替代 Ingress
resource "kubernetes_manifest" "httproute" {
  count = var.httproute_enabled ? 1 : 0

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = local.httproute_name
      namespace = local.namespace
    }
    spec = {
      parentRefs = [
        {
          name      = var.gateway_name      // 引用到的 Gateway 资源名称
          namespace = var.gateway_namespace // 引用到的 Gateway 资源所在命名空间
        }
      ]
      hostnames = var.httproute_hostnames // 访问域名列表，例如 ["speedtest.example.com"]

      // 流量转发规则列表，自动填充 backendRefs.name 为内部创建的 Service 名称
      rules = [
        for rule in var.httproute_rules : {
          matches = rule.matches
          backendRefs = [
            for backendRef in rule.backendRefs : {
              name = local.svc_name
              port = backendRef.port
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    kubernetes_namespace_v1.namespace
  ]
}
