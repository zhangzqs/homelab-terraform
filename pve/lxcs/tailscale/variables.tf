variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

# LXC容器基础配置
variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "tailscale"
}

variable "ubuntu_template_file_id" {
  description = "LXC容器模板文件ID"
  type        = string
}

variable "vm_id" {
  description = "LXC容器ID"
  type        = number
}

variable "network_interface_bridge" {
  description = "网络接口桥接设备"
  type        = string
  default     = "vmbr0"
}

variable "ipv4_address" {
  description = "容器IPv4地址"
  type        = string
}

variable "ipv4_address_cidr" {
  description = "容器IPv4地址CIDR前缀长度"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "容器IPv4网关"
  type        = string
}

# Tailscale配置
variable "tailscale_auth_key" {
  description = "Tailscale认证密钥(authkey)，用于自动加入Tailnet"
  type        = string
  sensitive   = true
}

variable "tailscale_advertise_routes" {
  description = "作为子网路由器暴露的CIDR子网列表，例如: [\"192.168.1.0/24\", \"10.0.0.0/16\"]"
  type        = list(string)
  default     = []
}

variable "tailscale_hostname" {
  description = "Tailscale网络中的主机名（可选），不设置则使用容器hostname"
  type        = string
  default     = ""
}

variable "tailscale_accept_routes" {
  description = "是否接受其他节点公告的子网路由"
  type        = bool
  default     = false
}

variable "tailscale_exit_node" {
  description = "是否作为出口节点（Exit Node）"
  type        = bool
  default     = false
}

variable "tailscale_ssh_enabled" {
  description = "是否启用Tailscale SSH"
  type        = bool
  default     = false
}

# 监控配置
variable "metrics_enabled" {
  description = "是否启用Prometheus指标监控"
  type        = bool
  default     = true
}

variable "metrics_port" {
  description = "Prometheus metrics端口"
  type        = number
  default     = 9001
}
