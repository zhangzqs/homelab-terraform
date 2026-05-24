locals {
  # 共享 SSH 连接信息（需存入 triggers_replace 供 destroy provisioner 使用）
  ssh_triggers = {
    ssh_host        = var.ssh_host
    ssh_port        = tostring(var.ssh_port)
    ssh_user        = var.ssh_user
    ssh_password    = var.ssh_password != null ? var.ssh_password : ""
    ssh_private_key = var.ssh_private_key != null ? (
      fileexists(var.ssh_private_key) ? file(var.ssh_private_key) : var.ssh_private_key
    ) : ""
  }

  # 所有资源共享的 trigger 基础
  common_triggers = merge(local.ssh_triggers, var.extra_triggers, {
    working_dir = var.working_dir
  })

  # 渲染脚本模板
  setup_script = templatefile("${path.module}/scripts/setup.sh", {
    mihomo_download_url = var.mihomo_download_url
  })

  uninstall_script = templatefile("${path.module}/scripts/uninstall.sh", {
    working_dir = var.working_dir
  })

  mihomo_service_content = templatefile("${path.module}/templates/mihomo.service.tpl", {
    working_dir = var.working_dir,
  })
}

# --------------------------------------------------
# 1. 安装 mihomo 二进制包
# --------------------------------------------------
resource "terraform_data" "install_mihomo" {
  triggers_replace = merge(local.common_triggers, {
    resource_type    = "install_mihomo"
    setup_hash       = md5(local.setup_script)
    uninstall_script = local.uninstall_script
  })

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    port        = tonumber(self.triggers_replace.ssh_port)
    user        = self.triggers_replace.ssh_user
    password    = self.triggers_replace.ssh_password != "" ? self.triggers_replace.ssh_password : null
    private_key = self.triggers_replace.ssh_private_key != "" ? self.triggers_replace.ssh_private_key : null
    timeout     = "2m"
  }

  # 上传安装脚本
  provisioner "file" {
    content     = local.setup_script
    destination = "/tmp/mihomo_setup.sh"
  }

  # 执行安装脚本
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/mihomo_setup.sh",
      "/tmp/mihomo_setup.sh",
      "rm -f /tmp/mihomo_setup.sh",
    ]
  }

  # ----- 销毁时：完全卸载 mihomo -----
  provisioner "file" {
    when        = destroy
    content     = self.triggers_replace.uninstall_script
    destination = "/tmp/mihomo_uninstall.sh"
  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
      "chmod +x /tmp/mihomo_uninstall.sh",
      "/tmp/mihomo_uninstall.sh",
      "rm -f /tmp/mihomo_uninstall.sh",
    ]
  }
}

# --------------------------------------------------
# 2. 配置 systemd 服务
# --------------------------------------------------
resource "terraform_data" "setup_systemd_service" {
  depends_on = [
    terraform_data.install_mihomo
  ]

  triggers_replace = merge(local.common_triggers, {
    resource_type = "setup_systemd_service"
    service_hash  = sha256(local.mihomo_service_content)
  })

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    port        = tonumber(self.triggers_replace.ssh_port)
    user        = self.triggers_replace.ssh_user
    password    = self.triggers_replace.ssh_password != "" ? self.triggers_replace.ssh_password : null
    private_key = self.triggers_replace.ssh_private_key != "" ? self.triggers_replace.ssh_private_key : null
    timeout     = "2m"
  }

  # 上传 systemd 单元文件
  provisioner "file" {
    content     = local.mihomo_service_content
    destination = "/etc/systemd/system/mihomo.service"
  }

  # 启用服务
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.working_dir}",
      "systemctl daemon-reload",
      "systemctl enable mihomo.service",
    ]
  }

  # ----- 销毁时：移除 systemd 单元文件 -----
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "systemctl stop mihomo.service 2>/dev/null || true",
      "systemctl disable mihomo.service 2>/dev/null || true",
      "rm -f /etc/systemd/system/mihomo.service",
      "systemctl daemon-reload",
    ]
  }
}

# --------------------------------------------------
# 3. 更新 mihomo 配置并重启服务
# --------------------------------------------------
resource "terraform_data" "update_mihomo_config" {
  depends_on = [
    terraform_data.setup_systemd_service
  ]

  triggers_replace = merge(local.common_triggers, {
    resource_type = "update_mihomo_config"
    config_hash   = sha256(var.mihomo_config_content)
  })

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    port        = tonumber(self.triggers_replace.ssh_port)
    user        = self.triggers_replace.ssh_user
    password    = self.triggers_replace.ssh_password != "" ? self.triggers_replace.ssh_password : null
    private_key = self.triggers_replace.ssh_private_key != "" ? self.triggers_replace.ssh_private_key : null
    timeout     = "2m"
  }

  # 上传 config.yaml
  provisioner "file" {
    content     = var.mihomo_config_content
    destination = "${var.working_dir}/config.yaml"
  }

  # 重启服务并验证启动成功
  provisioner "remote-exec" {
    inline = [
      "systemctl stop mihomo.service 2>/dev/null || true",
      "sleep 1",
      ": > ${var.working_dir}/mihomo.log 2>/dev/null || true",
      "systemctl start mihomo.service",
      "sleep 3",
      "if systemctl is-active --quiet mihomo.service; then",
      "  echo 'mihomo started successfully'",
      "else",
      "  echo 'mihomo failed to start, last 30 lines of log:'",
      "  tail -30 ${var.working_dir}/mihomo.log 2>/dev/null || true",
      "  exit 1",
      "fi",
    ]
  }

  # ----- 销毁时：删除配置文件 -----
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "rm -f ${self.triggers_replace.working_dir}/config.yaml 2>/dev/null || true",
    ]
  }
}
