variable "internal_vmbr_name" {
  description = "纯内网虚拟网桥名称"
  type        = string
  default     = "vmbr1"

  // 不能和vmbr0冲突
  validation {
    condition     = var.internal_vmbr_name != "vmbr0"
    error_message = "internal_vmbr_name 不能是 vmbr0，请选择其他名称。"
  }

  // 必须全是小写字母和数字，不能超过10个字符
  validation {
    condition     = can(regex("^[a-z0-9]{1,10}$", var.internal_vmbr_name))
    error_message = "internal_vmbr_name 必须只包含小写字母和数字，且长度不超过10个字符。"
  }
}

variable "internal_vmbr_address" {
  description = "纯内网虚拟网桥的IP/CIDR地址"
  type        = string
  default     = "10.242.0.1/24"
}

resource "proxmox_virtual_environment_network_linux_bridge" "internal_vmbr" {
  node_name = var.pve_node_name
  name      = var.internal_vmbr_name
  comment   = "纯内网虚拟网桥"
  address   = var.internal_vmbr_address
  autostart = true
}
