locals {
  # 转义挂载点路径用于 systemd 单元命名
  # 移除开头的 /，然后将所有 / 替换为 -
  # 例如: /mnt/usb-disk -> mnt-usb\\x2ddisk
  # 注意：实际的转义由脚本中的 systemd-escape 命令完成
  mount_unit_base     = trimsuffix(replace(trimsuffix(var.mount_point, "/"), "/", "-"), "-")
  mount_unit_name     = "${local.mount_unit_base}.mount"
  automount_unit_name = "${local.mount_unit_base}.automount"

  # 生成唯一的脚本文件名，避免并发执行时的冲突
  script_prefix = "/tmp/auto_mount_${var.disk_label}_${md5(var.mount_point)}"

  # 渲染验证脚本
  validate_script = templatefile("${path.module}/scripts/validate_disk.sh", {
    disk_uuid   = var.disk_uuid
    mount_point = var.mount_point
  })

  # 渲染安装脚本
  setup_script = templatefile("${path.module}/scripts/setup_auto_mount.sh", {
    mount_point       = var.mount_point
    disk_uuid         = var.disk_uuid
    disk_label        = var.disk_label
    filesystem_type   = var.filesystem_type
    mount_options     = var.mount_options
    automount_enabled = var.automount_enabled
    automount_timeout = var.automount_timeout
    owner             = var.owner
    group             = var.group
    permissions       = var.permissions
  })

  # 渲染卸载脚本
  uninstall_script = templatefile("${path.module}/scripts/uninstall_auto_mount.sh", {
    mount_point = var.mount_point
    disk_label  = var.disk_label
  })
}

# 上传并执行配置脚本
resource "null_resource" "setup_auto_mount" {
  # 当配置变化时重新执行
  triggers = {
    script_hash              = md5(local.setup_script)
    script_prefix            = local.script_prefix
    mount_point              = var.mount_point
    disk_uuid                = var.disk_uuid
    disk_label               = var.disk_label
    filesystem_type          = var.filesystem_type
    mount_options            = var.mount_options
    automount_enabled        = var.automount_enabled
    automount_timeout        = var.automount_timeout
    owner                    = var.owner
    group                    = var.group
    permissions              = var.permissions
    uninstall_script_content = local.uninstall_script
    # SSH 连接信息（destroy 时需要）
    ssh_host        = var.ssh_host
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
    ssh_password    = var.ssh_password
    ssh_private_key = var.ssh_private_key != null ? (fileexists(var.ssh_private_key) ? file(var.ssh_private_key) : var.ssh_private_key) : null
  }

  connection {
    type        = "ssh"
    host        = self.triggers.ssh_host
    port        = self.triggers.ssh_port
    user        = self.triggers.ssh_user
    password    = self.triggers.ssh_password
    private_key = self.triggers.ssh_private_key
  }

  # 上传验证脚本并执行
  provisioner "file" {
    content     = local.validate_script
    destination = "${local.script_prefix}_validate.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.script_prefix}_validate.sh",
      "${local.script_prefix}_validate.sh",
      "rm -f ${local.script_prefix}_validate.sh"
    ]
  }

  # 上传安装脚本
  provisioner "file" {
    content     = local.setup_script
    destination = "${local.script_prefix}_setup.sh"
  }

  # 执行安装脚本
  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.script_prefix}_setup.sh",
      "${local.script_prefix}_setup.sh",
      "rm -f ${local.script_prefix}_setup.sh"
    ]
  }

  provisioner "file" {
    when        = destroy
    content     = self.triggers.uninstall_script_content
    destination = "${self.triggers.script_prefix}_uninstall.sh"
  }

  # 销毁时执行卸载脚本
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "chmod +x ${self.triggers.script_prefix}_uninstall.sh",
      "${self.triggers.script_prefix}_uninstall.sh",
      "rm -f ${self.triggers.script_prefix}_uninstall.sh"
    ]
  }
}
