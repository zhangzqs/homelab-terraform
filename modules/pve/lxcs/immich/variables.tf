variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "immich"
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

variable "cpu_cores" {
  description = "LXC容器CPU核心数"
  type        = number
  default     = 2
}

variable "memory_dedicated" {
  description = "LXC容器内存大小(MB)"
  type        = number
  default     = 6144
}

variable "disk_size" {
  description = "LXC容器磁盘大小(GB)"
  type        = number
  default     = 200
}

variable "working_dir" {
  description = "Immich工作目录"
  type        = string
  default     = "/opt/immich"
}

variable "upload_location" {
  description = "Immich 媒体库存储路径"
  type        = string
  default     = "/opt/immich/library"
}

variable "db_data_location" {
  description = "Immich Postgres 数据路径"
  type        = string
  default     = "/opt/immich/postgres"
}

variable "immich_port" {
  description = "Immich Web 服务端口"
  type        = number
  default     = 2283
}

variable "timezone" {
  description = "Immich 容器时区"
  type        = string
  default     = "Asia/Shanghai"
}

variable "immich_version" {
  description = "Immich 镜像版本"
  type        = string
  default     = "v2"
}

variable "install_proxy" {
  description = "Immich 安装和镜像拉取使用的代理配置"
  type = object({
    http_proxy  = string
    https_proxy = string
  })
  default = null
}
