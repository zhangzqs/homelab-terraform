variable "k8s_api_server" {
  description = "Kubernetes API 服务器地址"
  type        = string
}

variable "k8s_cluster_ca_certificate" {
  description = "Kubernetes 集群 CA 证书内容, clusters.cluster.certificate-authority-data 字段的值"
  type        = string
}

variable "k8s_client_key" {
  description = "Kubernetes 客户端密钥内容, users.user.client-key-data 字段的值"
  type        = string
}

variable "k8s_client_certificate" {
  description = "Kubernetes 客户端证书内容, users.user.client-certificate-data 字段的值"
  type        = string
}
