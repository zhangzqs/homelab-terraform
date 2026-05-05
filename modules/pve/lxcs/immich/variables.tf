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

variable "host_mount_points" {
  description = "从宿主机挂载到容器的目录列表"
  type = list(object({
    host_path      = string
    container_path = string
    read_only      = optional(bool)
    shared         = optional(bool)
    backup         = optional(bool)
  }))
  default = []

  validation {
    condition = alltrue([
      for mp in var.host_mount_points :
      can(regex("^/", mp.host_path)) && can(regex("^/", mp.container_path))
    ])
    error_message = "宿主机路径和容器路径必须是绝对路径（以 / 开头）"
  }
}

variable "backup_target_dir" {
  description = "Immich 备份落盘目录；设置后会启用每日 rsync 备份"
  type        = string
  default     = null

  validation {
    condition     = var.backup_target_dir == null || can(regex("^/", var.backup_target_dir))
    error_message = "备份目录必须是绝对路径（以 / 开头）"
  }
}

variable "backup_schedule" {
  description = "Immich 每日备份的 crontab 表达式"
  type        = string
  default     = "0 3 * * *"
}

variable "mirror_target_dir" {
  description = "Immich 镜像同步目录；设置后会启用每日 rsync --delete mirror 任务"
  type        = string
  default     = null

  validation {
    condition     = var.mirror_target_dir == null || can(regex("^/", var.mirror_target_dir))
    error_message = "镜像目录必须是绝对路径（以 / 开头）"
  }
}

variable "mirror_schedule" {
  description = "Immich 每日 mirror 的 crontab 表达式"
  type        = string
  default     = "30 3 * * *"
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
