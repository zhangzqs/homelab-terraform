

output "vm_password" {
  value       = random_password.vm_password.result
  description = "虚拟机 root 用户的密码"
  sensitive   = true
}

output "vm_private_key" {
  value       = tls_private_key.vm_key.private_key_pem
  description = "虚拟机 SSH 私钥"
  sensitive   = true
}

output "vm_public_key" {
  value       = tls_private_key.vm_key.public_key_openssh
  description = "虚拟机 SSH 公钥"
}

output "vm_ip" {
  value       = var.ipv4_address
  description = "虚拟机 IP 地址"
}

output "k8s_kubeconfig" {
  value       = data.external.kubeconfig.result.kubeconfig
  description = "K3s kubeconfig 文件内容（已自动替换 server 地址为虚拟机 IP）"
  sensitive   = true
}

output "k8s_api_server" {
  value       = "https://${var.ipv4_address}:6443"
  description = "K3s API 服务器地址"
}

locals {
  parsed_kubeconfig = yamldecode(data.external.kubeconfig.result.kubeconfig)
}

output "k8s_cluster_ca_certificate" {
  value       = base64decode(local.parsed_kubeconfig.clusters[0].cluster["certificate-authority-data"])
  description = "Kubernetes 集群 CA 证书内容, clusters.cluster.certificate-authority-data 字段的值"
}

output "k8s_client_key" {
  value       = base64decode(local.parsed_kubeconfig.users[0].user["client-key-data"])
  description = "Kubernetes 客户端密钥内容, users.user.client-certificate-data 字段的值"
}

output "k8s_client_certificate" {
  value       = base64decode(local.parsed_kubeconfig.users[0].user["client-certificate-data"])
  description = "Kubernetes 客户端证书内容, users.user.client-key-data 字段的值"
}
