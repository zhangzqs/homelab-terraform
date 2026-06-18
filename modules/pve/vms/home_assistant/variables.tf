variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

variable "pve_host_ssh_params" {
  description = "Proxmox VE 宿主机 SSH 连接参数（用于下载并解压 HAOS 镜像）"
  type = object({
    ssh_host     = string
    ssh_port     = optional(number, 22)
    ssh_user     = optional(string, "root")
    ssh_password = string
  })
}

variable "vm_id" {
  description = "虚拟机 ID"
  type        = number
}

variable "name" {
  description = "虚拟机名称"
  type        = string
  default     = "home-assistant"
}

variable "haos_version" {
  description = "Home Assistant OS 版本号，对应 GitHub release tag，例如 \"18.0\""
  type        = string
  default     = "18.0"
}

variable "haos_image_datastore_id" {
  description = "存放 HAOS qcow2 镜像的 datastore（仅供首次 import，使用 PVE 默认 ISO 目录式存储）"
  type        = string
  default     = "local"
}

variable "config_iso_datastore_id" {
  description = "存放 CONFIG 注入 ISO 的 datastore"
  type        = string
  default     = "local"
}

variable "disk_datastore_id" {
  description = "VM 系统盘所在 datastore"
  type        = string
  default     = "local-lvm"
}

variable "network_interface_bridge" {
  description = "网络接口桥接设备"
  type        = string
  default     = "vmbr0"
}

variable "mac_address" {
  description = "VM 网卡 MAC 地址，建议固定以便路由器侧绑定（可选）"
  type        = string
  default     = null
}

variable "ipv4_address" {
  description = "虚拟机 IPv4 地址"
  type        = string
}

variable "ipv4_address_cidr" {
  description = "虚拟机 IPv4 地址 CIDR 前缀长度"
  type        = number
  default     = 24
}

variable "ipv4_gateway" {
  description = "虚拟机 IPv4 网关"
  type        = string
}

variable "ipv4_dns" {
  description = "虚拟机 IPv4 DNS（多个用分号分隔，符合 NetworkManager keyfile 语法）"
  type        = string
  default     = "223.5.5.5;119.29.29.29"
}

variable "cpu_cores" {
  description = "CPU 核心数"
  type        = number
  default     = 2
}

variable "memory" {
  description = "内存大小 (MB)"
  type        = number
  default     = 4096
}

variable "disk_size" {
  description = "系统盘大小 (GB)，HAOS 默认 32GB 即可"
  type        = number
  default     = 32
}

variable "usb_devices" {
  description = "USB 直通设备列表，host 字段格式为 \"vendor_id:product_id\"，如 \"10c4:ea60\""
  type = list(object({
    host = string
    usb3 = optional(bool, false)
  }))
  default = []
}
