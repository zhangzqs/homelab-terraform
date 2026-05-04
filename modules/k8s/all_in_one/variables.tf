variable "k8s_api_server" {
  description = "Kubernetes API 服务器地址"
  type        = string
}

variable "k8s_cluster_ca_certificate" {
  description = "Kubernetes 集群 CA 证书内容, clusters.cluster.certificate-authority-data 字段的值"
  type        = string
}

variable "k8s_client_key" {
  description = "Kubernetes 客户端密钥内容, users.user.client-certificate-data 字段的值"
  type        = string
}

variable "k8s_client_certificate" {
  description = "Kubernetes 客户端证书内容, users.user.client-key-data 字段的值"
  type        = string
}

variable "httproute_base_hostname" {
  description = "HTTPRoute 基础访问域名，用于构建各服务的完整访问域名"
  type        = string
}

variable "nfs_server" {
  description = "NFS 服务器地址"
  type        = string
}

variable "nfs_share_path" {
  description = "NFS 共享路径"
  type        = string
}
