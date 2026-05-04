variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "storage-server"
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

variable "enabled_protocols" {
  description = "启用的存储协议列表"
  type        = set(string)
  default     = []
  validation {
    condition = alltrue([
      for protocol in var.enabled_protocols : contains(["nfs", "smb"], protocol)
    ])
    error_message = "支持的协议: nfs, smb"
  }
}

# NFS 配置
variable "nfs_exports" {
  description = "NFS导出目录配置列表"
  type = list(object({
    name            = string                                                               # 导出名称/标识
    path            = string                                                               # 导出路径
    allowed_network = optional(string, "*")                                                # 允许访问的网络范围
    options         = optional(string, "rw,sync,no_subtree_check,no_root_squash,insecure") # 导出选项
  }))
  default = []
}

# SMB 配置
variable "smb_shares" {
  description = "SMB共享目录配置列表"
  type = list(object({
    name      = string         # 共享名称
    path      = string         # 共享路径
    read_only = optional(bool) # 是否只读，默认 false
  }))
  default = []
}

variable "smb_user" {
  description = "SMB用户账户配置（dockur/samba 单用户模式）"
  type = object({
    username = string # 用户名
    password = string # 密码
  })
  default = {
    username = "user"
    password = "pass"
  }
  sensitive = true
}


variable "disk_size" {
  description = "LXC容器磁盘大小(GB)"
  type        = number
  default     = 50
}

variable "disk_datastore_id" {
  description = "LXC容器磁盘存储位置"
  type        = string
  default     = "local-lvm"
}

variable "cpu_cores" {
  description = "LXC容器CPU核心数"
  type        = number
  default     = 2
}

variable "memory_dedicated" {
  description = "LXC容器内存大小(MB)"
  type        = number
  default     = 1024
}

variable "memory_swap" {
  description = "LXC容器swap大小(MB)"
  type        = number
  default     = 0
}

# 宿主机挂载点配置
variable "host_mount_points" {
  description = "从宿主机挂载到容器的目录列表"
  type = list(object({
    host_path      = string         # 宿主机路径
    container_path = string         # 容器内路径
    read_only      = optional(bool) # 是否只读，默认 false
    shared         = optional(bool) # 是否共享，默认 false
    backup         = optional(bool) # 是否备份，默认 false
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

variable "prevent_container_destroy" {
  description = "是否禁止通过 Terraform 销毁该容器"
  type        = bool
  default     = true
}
