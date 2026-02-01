variable "ubuntu_24_04_enabled" {
  description = "是否启用 Ubuntu 24.04 云镜像的下载"
  type        = bool
  default     = false
}

variable "ubuntu_24_04_datastore_id" {
  description = "存储 Ubuntu 24.04 云镜像的 Proxmox 数据存储 ID"
  type        = string
  default     = "local"
}

resource "proxmox_virtual_environment_download_file" "ubuntu_24_04_cloud_image" {
  count = var.ubuntu_24_04_enabled ? 1 : 0

  content_type = "import"
  datastore_id = var.ubuntu_24_04_datastore_id
  node_name    = var.pve_node_name
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.qcow2"
}

output "ubuntu_24_04_id" {
  value       = length(proxmox_virtual_environment_download_file.ubuntu_24_04_cloud_image) > 0 ? proxmox_virtual_environment_download_file.ubuntu_24_04_cloud_image[0].id : ""
  description = "Ubuntu 24.04 Cloud Image 文件 ID"
}
