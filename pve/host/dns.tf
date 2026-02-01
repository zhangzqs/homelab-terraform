variable "dns_servers" {
  description = "Proxmox VE 节点的 DNS 服务器列表"
  type        = list(string)
  default = [
    "223.5.5.5",    // 阿里云DNS服务器
    "119.29.29.29", // 腾讯DNS服务器
    "8.8.8.8",      // Google DNS服务器
  ]
}

data "proxmox_virtual_environment_dns" "pve_node_dns_configuration" {
  node_name = var.pve_node_name
}

resource "proxmox_virtual_environment_dns" "pve_node_dns_configuration" {
  node_name = var.pve_node_name
  domain    = data.proxmox_virtual_environment_dns.pve_node_dns_configuration.domain
  servers   = var.dns_servers
}
