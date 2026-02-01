variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "nfs-server"
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

variable "nfs_export_path" {
  description = "NFS服务器导出路径"
  type        = string
  default     = "/srv/nfs/k3s"
}

variable "nfs_allowed_network" {
  description = "允许访问NFS的网络范围"
  type        = string
  default     = "192.168.242.0/24"
}

variable "disk_size" {
  description = "LXC容器磁盘大小(GB)"
  type        = number
  default     = 50
}
