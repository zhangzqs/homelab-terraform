variable "ubuntu_24_04_enabled" {
  description = "是否启用 Ubuntu 24.04 LXC 模板的下载"
  type        = bool
  default     = false
}

variable "ubuntu_24_04_datastore_id" {
  description = "存储 Ubuntu 24.04 LXC 模板的 Proxmox 数据存储 ID"
  type        = string
  default     = "local"
}


resource "proxmox_virtual_environment_file" "ubuntu_24_04" {
  node_name    = var.pve_node_name
  content_type = "vztmpl" // LXC容器模板
  datastore_id = var.ubuntu_24_04_datastore_id

  source_file {
    path = "http://download.proxmox.com/images/system/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
  }
}


output "ubuntu_24_04_id" {
  value       = length(proxmox_virtual_environment_file.ubuntu_24_04) > 0 ? proxmox_virtual_environment_file.ubuntu_24_04[0].id : ""
  description = "The ID of the Ubuntu 24.04 LXC template file."
}
