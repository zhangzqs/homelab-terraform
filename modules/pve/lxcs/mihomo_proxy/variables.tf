variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "mihomo-proxy"
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
  description = "容器IPv4地址配置"
  type        = string
  default     = "dhcp"
}

variable "ipv4_address_cidr" {
  description = "容器IPv4地址CIDR前缀长度"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "容器IPv4网关配置"
  type        = string
  default     = null
}

variable "working_dir" {
  description = "工作目录"
  type        = string
  default     = "/root/mihomo"
}

variable "mihomo_config_content" {
  description = "Mihomo配置文件内容"
  type        = string
  default     = "port: 7890"
}
