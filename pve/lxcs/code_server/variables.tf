variable "hostname" {
  description = "LXC容器主机名"
  type        = string
  default     = "code-server"
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
  description = "code-server工作目录"
  type        = string
  default     = "/root/code-server"
}

variable "code_server_password" {
  description = "code-server访问密码(留空则自动生成)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "code_server_port" {
  description = "code-server监听端口"
  type        = number
  default     = 8080
}
