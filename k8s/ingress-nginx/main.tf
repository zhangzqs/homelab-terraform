resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = var.ingress_nginx_namespace
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = var.ingress_nginx_service_type
          nodePorts = {
            http  = var.ingress_nginx_http_nodeport
            https = var.ingress_nginx_https_nodeport
          }
        }
        metrics = {
          enabled = true
        }
        replicaCount = 1
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
