# ==========================================
# 示例：使用 lxc_mount_point 模块
# ==========================================

# 此文件展示了如何使用 lxc_mount_point 模块
# 取消注释并修改相应的配置即可使用

# ==========================================
# 示例 1: 基本用法
# ==========================================

# module "lxc_mount_example" {
#   source = "../utils/lxc_mount_point"
#
#   # SSH 连接参数
#   ssh_host     = "192.168.1.100"
#   ssh_user     = "root"
#   ssh_password = "your-password"
#
#   # LXC 容器配置
#   container_id   = 243
#   mount_point_id = "mp0"
#
#   # 挂载路径
#   host_path      = "/mnt/hdd-disk"
#   container_path = "/mnt/mydisk"
#
#   # 挂载后重启容器
#   restart_container = true
# }

# ==========================================
# 示例 2: 在 storage_server 中使用
# ==========================================

# 配合 auto_disk_mount 模块使用，将自动挂载的磁盘挂载到 LXC 容器

# variable "pve_host_ssh_params" {
#   type = object({
#     ssh_host     = string
#     ssh_port     = optional(number, 22)
#     ssh_user     = optional(string, "root")
#     ssh_password = string
#   })
# }
#
# module "auto_disk_mount" {
#   source           = "../utils/auto_disk_mount"
#   ssh_host         = var.pve_host_ssh_params.ssh_host
#   ssh_port         = var.pve_host_ssh_params.ssh_port
#   ssh_user         = var.pve_host_ssh_params.ssh_user
#   ssh_password     = var.pve_host_ssh_params.ssh_password
#   disk_uuid        = "89ae166c-3fcf-4a41-ad02-fca474f380ca"
#   disk_label       = "hdd-disk"
#   mount_point      = "/mnt/hdd-disk"
#   filesystem_type  = "ext4"
#   mount_options    = "defaults,nofail"
# }
#
# module "lxc_mount_hdd" {
#   source = "../utils/lxc_mount_point"
#
#   # 使用相同的 SSH 参数
#   ssh_host     = var.pve_host_ssh_params.ssh_host
#   ssh_port     = var.pve_host_ssh_params.ssh_port
#   ssh_user     = var.pve_host_ssh_params.ssh_user
#   ssh_password = var.pve_host_ssh_params.ssh_password
#
#   # 挂载自动挂载的磁盘到容器
#   container_id   = 243
#   mount_point_id = "mp0"
#   host_path      = module.auto_disk_mount.mount_point
#   container_path = "/mnt/host_hdd_disk"
#
#   # 依赖关系：确保磁盘先挂载到宿主机
#   depends_on = [module.auto_disk_mount]
# }

# ==========================================
# 示例 3: 挂载多个目录到同一容器
# ==========================================

# module "lxc_mount_hdd" {
#   source = "../utils/lxc_mount_point"
#
#   ssh_host     = var.pve_host_ssh_params.ssh_host
#   ssh_user     = var.pve_host_ssh_params.ssh_user
#   ssh_password = var.pve_host_ssh_params.ssh_password
#
#   container_id   = 243
#   mount_point_id = "mp0"
#   host_path      = "/mnt/hdd-disk"
#   container_path = "/mnt/hdd"
# }
#
# module "lxc_mount_ssd" {
#   source = "../utils/lxc_mount_point"
#
#   ssh_host     = var.pve_host_ssh_params.ssh_host
#   ssh_user     = var.pve_host_ssh_params.ssh_user
#   ssh_password = var.pve_host_ssh_params.ssh_password
#
#   container_id   = 243
#   mount_point_id = "mp1"  # 注意：使用不同的挂载点 ID
#   host_path      = "/mnt/ssd-disk"
#   container_path = "/mnt/ssd"
# }
#
# module "lxc_mount_backup" {
#   source = "../utils/lxc_mount_point"
#
#   ssh_host     = var.pve_host_ssh_params.ssh_host
#   ssh_user     = var.pve_host_ssh_params.ssh_user
#   ssh_password = var.pve_host_ssh_params.ssh_password
#
#   container_id   = 243
#   mount_point_id = "mp2"  # 注意：使用不同的挂载点 ID
#   host_path      = "/mnt/backup"
#   container_path = "/mnt/backup"
#
#   # 带挂载选项
#   mount_options = ["backup=1", "replicate=1"]
# }

# ==========================================
# 示例 4: 使用 SSH 私钥认证
# ==========================================

# module "lxc_mount_with_key" {
#   source = "../utils/lxc_mount_point"
#
#   ssh_host        = "192.168.1.100"
#   ssh_user        = "root"
#   ssh_private_key = file("~/.ssh/id_rsa")  # 或直接传入私钥内容
#
#   container_id   = 243
#   mount_point_id = "mp0"
#   host_path      = "/mnt/hdd-disk"
#   container_path = "/mnt/mydisk"
# }

# ==========================================
# 示例 5: 停止容器后挂载
# ==========================================

# 适用于需要在容器停止状态下进行挂载的场景

# module "lxc_mount_with_stop" {
#   source = "../utils/lxc_mount_point"
#
#   ssh_host     = "192.168.1.100"
#   ssh_user     = "root"
#   ssh_password = "your-password"
#
#   container_id   = 243
#   mount_point_id = "mp0"
#   host_path      = "/mnt/hdd-disk"
#   container_path = "/mnt/mydisk"
#
#   # 先停止容器再挂载，然后重启
#   stop_before_mount = true
#   restart_container = true
# }

# ==========================================
# 示例 6: 不自动重启容器
# ==========================================

# 适用于不想自动重启容器的场景，稍后可以手动重启

# module "lxc_mount_no_restart" {
#   source = "../utils/lxc_mount_point"
#
#   ssh_host     = "192.168.1.100"
#   ssh_user     = "root"
#   ssh_password = "your-password"
#
#   container_id   = 243
#   mount_point_id = "mp0"
#   host_path      = "/mnt/hdd-disk"
#   container_path = "/mnt/mydisk"
#
#   # 不自动重启容器
#   restart_container = false
# }
#
# # 稍后可以通过其他方式重启容器
# # 例如使用 null_resource 或手动重启
