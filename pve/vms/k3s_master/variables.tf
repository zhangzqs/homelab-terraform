variable "vm_id" {
  description = "虚拟机ID"
  type        = number
}

variable "cloud_init_config_datastore_id" {
  description = "Cloud-Init 配置文件存储位置 ID"
  type        = string
  default     = "local"
}

variable "disk_datastore_id" {
  description = "数据存储ID"
  type        = string
  default     = "local-lvm"
}

variable "name" {
  description = "虚拟机名称"
  type        = string
  default     = "k3s-master"
}

variable "hostname" {
  description = "虚拟机内的主机名"
  type        = string
  default     = "k3s-master"
}

variable "ubuntu_cloud_image_id" {
  description = "Ubuntu Cloud Image 资源 ID"
  type        = string
}

variable "network_interface_bridge" {
  description = "网络接口桥接设备"
  type        = string
  default     = "vmbr0"
}

variable "ipv4_address" {
  description = "虚拟机IPv4地址"
  type        = string
}

variable "ipv4_address_cidr" {
  description = "虚拟机IPv4地址CIDR前缀长度"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "虚拟机IPv4网关配置"
  type        = string
}

variable "cpu_cores" {
  description = "CPU核心数"
  type        = number
  default     = 4
}

variable "memory" {
  description = "内存大小(MB)"
  type        = number
  default     = 4096
}

variable "memory_floating_enabled" {
  description = "是否启用浮动内存"
  type        = bool
  default     = true
}

variable "disk_size" {
  description = "磁盘大小(GB)"
  type        = number
  default     = 32
}

variable "containerd_proxy" {
  description = "Containerd 代理配置"
  type = object({
    http_proxy  = string
    https_proxy = string
    no_proxy    = optional(string, "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16")
  })
  default = null
}
