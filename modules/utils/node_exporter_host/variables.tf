variable "ssh_host" {
  description = "目标主机地址"
  type        = string
}

variable "ssh_port" {
  description = "SSH端口"
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "SSH端口必须在1-65535之间"
  }
}

variable "ssh_user" {
  description = "SSH用户名"
  type        = string
  default     = "root"
}

variable "ssh_password" {
  description = "SSH密码（与ssh_private_key二选一）"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key" {
  description = "SSH私钥内容或文件路径（与ssh_password二选一）"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_private_key_path" {
  description = "SSH私钥文件路径"
  type        = string
  default     = null
}

variable "listen_address" {
  description = "node_exporter 监听地址"
  type        = string

  validation {
    condition     = can(regex("^[0-9A-Za-z._:-]+$", var.listen_address))
    error_message = "监听地址只能包含字母、数字、点、下划线、冒号和短横线"
  }
}

variable "listen_port" {
  description = "node_exporter 监听端口"
  type        = number
  default     = 9100

  validation {
    condition     = var.listen_port > 0 && var.listen_port <= 65535
    error_message = "监听端口必须在1-65535之间"
  }
}

variable "container_name" {
  description = "Podman 容器名称"
  type        = string
  default     = "node-exporter-host"

  validation {
    condition     = can(regex("^[0-9A-Za-z][0-9A-Za-z_.-]*$", var.container_name))
    error_message = "容器名称只能包含字母、数字、点、下划线和短横线，且必须以字母或数字开头"
  }
}

variable "container_image" {
  description = "node_exporter 容器镜像"
  type        = string
  default     = "quay.io/prometheus/node-exporter:v1.9.1"

  validation {
    condition     = can(regex("^[0-9A-Za-z./:@_-]+$", var.container_image))
    error_message = "容器镜像只能包含镜像地址所需的安全字符"
  }
}
