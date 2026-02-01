variable "nfs_server_ip" {
  description = "NFS 服务器 IP 地址"
  type        = string
}

variable "nfs_export_path" {
  description = "NFS 服务器导出路径"
  type        = string
  default     = "/srv/nfs/k3s"
}

variable "namespace" {
  description = "Kubernetes 命名空间"
  type        = string
  default     = "nfs-demo"
}

variable "storage_capacity" {
  description = "PersistentVolume 存储容量"
  type        = string
  default     = "10Gi"
}
