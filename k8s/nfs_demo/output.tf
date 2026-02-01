output "namespace" {
  value       = kubernetes_namespace_v1.nfs_demo.metadata[0].name
  description = "创建的 Kubernetes 命名空间名称"
}

output "pv_name" {
  value       = kubernetes_persistent_volume_v1.nfs_pv.metadata[0].name
  description = "创建的 PersistentVolume 名称"
}

output "pvc_name" {
  value       = kubernetes_persistent_volume_claim_v1.nfs_pvc.metadata[0].name
  description = "创建的 PersistentVolumeClaim 名称"
}

output "demo_pod_name" {
  value       = kubernetes_pod_v1.nfs_demo_pod.metadata[0].name
  description = "创建的演示 Pod 名称"
}
