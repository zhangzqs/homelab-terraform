// 这个模块能正常工作需要提前依赖
// terraform apply -target=module.pve_vm_k3s_master
// 这个资源的创建
module "k8s" {
  source = "../k8s/all_in_one"

  k8s_api_server             = module.pve_vm_k3s_master.k8s_api_server
  k8s_cluster_ca_certificate = module.pve_vm_k3s_master.k8s_cluster_ca_certificate
  k8s_client_key             = module.pve_vm_k3s_master.k8s_client_key
  k8s_client_certificate     = module.pve_vm_k3s_master.k8s_client_certificate

  httproute_base_hostname = var.home_base_domain
  nfs_server              = module.pve_lxc_instance_storage_server.server_ip
  nfs_share_path          = "/root/test_nfs"
}
