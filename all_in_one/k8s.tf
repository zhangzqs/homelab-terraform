module "k8s" {
  source = "../k8s/all_in_one"

  providers = {
    helm       = helm
    kubernetes = kubernetes
  }
}

provider "helm" {
  kubernetes = {
    host                   = module.pve_vm_k3s_master.k8s_api_server
    cluster_ca_certificate = module.pve_vm_k3s_master.k8s_cluster_ca_certificate
    client_key             = module.pve_vm_k3s_master.k8s_client_key
    client_certificate     = module.pve_vm_k3s_master.k8s_client_certificate
  }
}

provider "kubernetes" {
  host                   = module.pve_vm_k3s_master.k8s_api_server
  cluster_ca_certificate = module.pve_vm_k3s_master.k8s_cluster_ca_certificate
  client_key             = module.pve_vm_k3s_master.k8s_client_key
  client_certificate     = module.pve_vm_k3s_master.k8s_client_certificate
}
