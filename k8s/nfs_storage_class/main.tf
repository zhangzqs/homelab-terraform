resource "kubernetes_storage_class_v1" "storage_class" {
  metadata {
    name = "nfs-csi-storage-class"
  }
  storage_provisioner    = "nfs.csi.k8s.io"
  reclaim_policy         = "Delete"    // 删除PVC时自动删除PV
  volume_binding_mode    = "Immediate" // PVC创建后，立即创建PV并绑定PVC
  allow_volume_expansion = true        // 允许用户通过编辑 PVC 的 .spec.resources.requests.storage字段来请求更大的存储空间
  parameters = {
    server   = var.nfs_server
    share    = var.nfs_share_path
    subDir   = "$${pvc.metadata.name}"
    onDelete = "retain" // 删除PV时保留数据
  }
  mount_options = [
    "nfsvers=4.1"
  ]
}

output "storage_class_name" {
  value = kubernetes_storage_class_v1.storage_class.metadata[0].name
}
