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
  description = "Home Assistant OS 版本号，对应 GitHub release tag，例如 \"17.3\""
  type        = string
  default     = "17.3"
}

variable "haos_image_datastore_id" {
  description = "存放 HAOS qcow2 镜像的 datastore（仅供首次 import，使用 PVE 默认 ISO 目录式存储）"
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

variable "interface_name" {
  description = "VM 内部网卡接口名，用于在 HAOS 起来后通过 `nmcli con modify 'Supervisor <interface_name>' ...` 注入静态 IP。PVE q35 + virtio + ovmf 默认是 `enp6s18`。"
  type        = string
  default     = "enp6s18"
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

variable "download_proxy" {
  description = "下载 HAOS 镜像时使用的 HTTP 代理（可选）。设置后 wget 会带 https_proxy/http_proxy。直连 GitHub 慢的内网建议指向 mihomo。"
  type = object({
    http_proxy  = string
    https_proxy = string
  })
  default = null
}

variable "trusted_proxies" {
  description = "HA configuration.yaml 的 http.trusted_proxies 列表（CIDR 或单 IP）。非空时模块会通过 qm guest exec 把 `http.use_x_forwarded_for + trusted_proxies` 写到 HA 配置；用于走 nginx 反代访问 HA 的场景。onboarding 未完成时该步骤会静默跳过，重跑 apply 即生效。"
  type        = list(string)
  default     = []
}

variable "ha_config_path" {
  description = "HA configuration.yaml 在 HAOS 内部的路径"
  type        = string
  default     = "/mnt/data/supervisor/homeassistant/configuration.yaml"
}
