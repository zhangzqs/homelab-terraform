locals {
  # 生成挂载配置字符串
  # 格式: /host/path,mp=/container/path[,option1=value1,option2=value2,...]
  mount_config_string = join(",", concat(
    ["${var.host_path},mp=${var.container_path}"],
    var.mount_options
  ))

  # 生成唯一的脚本文件前缀，避免并发冲突
  script_prefix = "/tmp/lxc_mount_${var.container_id}_${var.mount_point_id}_${md5(var.host_path)}"

  # 处理 SSH 私钥（如果是文件路径则读取，否则作为内容使用）
  ssh_private_key_content = var.ssh_private_key != null ? (
    fileexists(var.ssh_private_key) ? file(var.ssh_private_key) : var.ssh_private_key
  ) : null
}

# ==========================================
# 主资源：配置 LXC 挂载点
# ==========================================

resource "null_resource" "lxc_mount_point" {
  # 当配置变化时重新执行
  triggers = {
    container_id        = var.container_id
    mount_point_id      = var.mount_point_id
    host_path           = var.host_path
    container_path      = var.container_path
    mount_config_string = local.mount_config_string
    restart_container   = var.restart_container
    stop_before_mount   = var.stop_before_mount

    # 保存 SSH 连接信息供 destroy 时使用
    ssh_host        = var.ssh_host
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
    ssh_password    = var.ssh_password
    ssh_private_key = local.ssh_private_key_content
    script_prefix   = local.script_prefix
  }

  connection {
    type        = "ssh"
    host        = self.triggers.ssh_host
    port        = self.triggers.ssh_port
    user        = self.triggers.ssh_user
    password    = self.triggers.ssh_password
    private_key = self.triggers.ssh_private_key
  }

  # ==========================================
  # 上传并执行挂载脚本
  # ==========================================

  provisioner "file" {
    content = templatefile("${path.module}/scripts/mount_lxc.sh", {
      container_id        = var.container_id
      mount_point_id      = var.mount_point_id
      host_path           = var.host_path
      container_path      = var.container_path
      mount_config_string = local.mount_config_string
      restart_container   = var.restart_container
      stop_before_mount   = var.stop_before_mount
    })
    destination = "${local.script_prefix}_mount.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x ${local.script_prefix}_mount.sh",
      "${local.script_prefix}_mount.sh",
      "rm -f ${local.script_prefix}_mount.sh"
    ]
  }

  # ==========================================
  # 销毁时执行卸载脚本
  # ==========================================

  provisioner "file" {
    when = destroy
    content = templatefile("${path.module}/scripts/unmount_lxc.sh", {
      container_id      = self.triggers.container_id
      mount_point_id    = self.triggers.mount_point_id
      restart_container = self.triggers.restart_container
    })
    destination = "${self.triggers.script_prefix}_unmount.sh"
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "chmod +x ${self.triggers.script_prefix}_unmount.sh",
      "${self.triggers.script_prefix}_unmount.sh",
      "rm -f ${self.triggers.script_prefix}_unmount.sh"
    ]
  }
}
