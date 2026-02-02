variable "pve_node_name" {
  description = "Proxmox 节点名称"
  type        = string
  default     = "pve"
}

variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "coredns"
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

variable "working_dir" {
  description = "CoreDNS工作目录"
  type        = string
  default     = "/root/coredns"
}

variable "dns_port" {
  description = "CoreDNS监听端口"
  type        = number
  default     = 53
}

variable "metrics_port" {
  description = "CoreDNS Prometheus metrics端口"
  type        = number
  default     = 9153
}

variable "upstream_dns_servers" {
  description = "上游DNS服务器列表，支持普通DNS、DoH和DoT地址"
  type        = list(string)
  default = [
    "223.5.5.5",    # 阿里DNS
    "119.29.29.29", # 腾讯DNS
  ]
}

variable "cache_ttl" {
  description = "DNS缓存TTL（秒）"
  type        = number
  default     = 3600
}

variable "cache_prefetch" {
  description = "缓存预取数量"
  type        = number
  default     = 10
}

variable "cache_serve_stale" {
  description = "缓存过期后继续服务时间（秒）"
  type        = number
  default     = 86400
}

variable "enable_dnssec" {
  description = "是否启用DNSSEC验证"
  type        = bool
  default     = false
}

variable "hosts" {
  description = "Hosts记录列表（精确匹配）"
  type = list(object({
    ip       = string
    hostname = string
  }))
  default = []
}

variable "wildcard_domains" {
  description = "泛域名配置列表"
  type = list(object({
    zone = string # 域名后缀，如 example.com（不含*）
    ip   = string
  }))
  default = []
}
