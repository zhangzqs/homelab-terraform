# 部署 NGINX Gateway Fabric
resource "helm_release" "nginx_gateway_fabric" {
  name             = "nginx-gateway-fabric"
  repository       = "oci://ghcr.io/nginx/charts"
  chart            = "nginx-gateway-fabric"
  version          = var.nginx_gateway_fabric_chart_version
  namespace        = var.gateway_api_namespace
  create_namespace = true

  values = [
    yamlencode({
      nginx = {
        replicaCount = 1
        service = {
          type = var.gateway_service_type
          ports = [
            {
              name       = "http"
              port       = 80
              targetPort = 80
              nodePort   = var.gateway_http_nodeport
            },
            {
              name       = "https"
              port       = 443
              targetPort = 443
              nodePort   = var.gateway_https_nodeport
            }
          ]
        }
      }
      nginxGateway = {
        gatewayClassName = "nginx"
        replicaCount     = 1
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]
}

# 创建 Gateway 资源
resource "kubernetes_manifest" "gateway" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = var.gateway_name
      namespace = var.gateway_api_namespace
    }
    spec = {
      gatewayClassName = "nginx"
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = {
              from = "All"
            }
          }
        }
      ]
    }
  }

  depends_on = [helm_release.nginx_gateway_fabric]
}
