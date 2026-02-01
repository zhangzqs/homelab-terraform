provider "helm" {
  kubernetes = {
    host                   = var.k8s_api_server
    cluster_ca_certificate = var.k8s_cluster_ca_certificate
    client_key             = var.k8s_client_key
    client_certificate     = var.k8s_client_certificate
  }
}
