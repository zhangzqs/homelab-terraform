
module "ingress_nginx" {
  source = "../ingress-nginx"

  k8s_api_server             = var.k8s_api_server
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  k8s_client_key             = var.k8s_client_key
  k8s_client_certificate     = var.k8s_client_certificate
}

module "speedtest" {
  source = "../speedtest"

  k8s_api_server             = var.k8s_api_server
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  k8s_client_key             = var.k8s_client_key
  k8s_client_certificate     = var.k8s_client_certificate
  speedtest_enable_ingress   = true
}

module "plantuml" {
  source = "../plantuml"

  k8s_api_server             = var.k8s_api_server
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  k8s_client_key             = var.k8s_client_key
  k8s_client_certificate     = var.k8s_client_certificate
}
