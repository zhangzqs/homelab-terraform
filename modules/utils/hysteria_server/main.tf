locals {
  resolved_ssh_private_key = var.ssh_private_key != null ? var.ssh_private_key : null

  ssh = {
    host        = var.ssh_host
    port        = var.ssh_port
    user        = var.ssh_user
    password    = var.ssh_password
    private_key = local.resolved_ssh_private_key
  }

  config_yaml = templatefile("${path.module}/config.yaml.tftpl", {
    domain     = var.domain
    email      = var.acme_email
    password   = var.auth_password
    listen     = ":${var.listen_port}"
    masquerade = var.masquerade_url
  })
}

# 安装 Hysteria 2 二进制 + 防火墙（只在首次或连接信息/端口变化时执行）
resource "terraform_data" "hysteria_install" {
  triggers_replace = {
    ssh_host        = var.ssh_host
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
    ssh_password    = var.ssh_password
    ssh_private_key = local.resolved_ssh_private_key
    listen_port     = var.listen_port
  }

  lifecycle {
    precondition {
      condition = (
        var.ssh_password != null ||
        var.ssh_private_key != null
      )
      error_message = "至少需要配置一种 SSH 认证方式（ssh_password 或 ssh_private_key）"
    }
  }

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    port        = self.triggers_replace.ssh_port
    user        = self.triggers_replace.ssh_user
    password    = self.triggers_replace.ssh_password
    private_key = self.triggers_replace.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "test -f /etc/hysteria && rm -f /etc/hysteria; mkdir -p /etc/hysteria",
      "if command -v ufw >/dev/null 2>&1; then ufw allow ${var.listen_port}/udp; fi",
      "if command -v firewall-cmd >/dev/null 2>&1; then firewall-cmd --permanent --add-port=${var.listen_port}/udp && firewall-cmd --reload; fi",
      "curl -fsSL https://get.hy2.sh/ | bash",
    ]
  }

  provisioner "remote-exec" {
    when = destroy

    inline = [
      "systemctl disable --now hysteria-server.service || true",
      "rm -rf /etc/hysteria",
      "rm -f /usr/local/bin/hysteria",
      "rm -f /etc/systemd/system/hysteria-server.service /etc/systemd/system/hysteria-server@.service",
      "systemctl daemon-reload || true",
    ]
  }
}

# 渲染配置 + 重启服务（配置变更时只替换此资源，不重装）
resource "terraform_data" "hysteria_config" {
  triggers_replace = {
    config_hash     = sha256(local.config_yaml)
    ssh_host        = var.ssh_host
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
    ssh_password    = var.ssh_password
    ssh_private_key = local.resolved_ssh_private_key
  }

  depends_on = [terraform_data.hysteria_install]

  connection {
    type        = "ssh"
    host        = self.triggers_replace.ssh_host
    port        = self.triggers_replace.ssh_port
    user        = self.triggers_replace.ssh_user
    password    = self.triggers_replace.ssh_password
    private_key = self.triggers_replace.ssh_private_key
  }

  provisioner "file" {
    content     = local.config_yaml
    destination = "/etc/hysteria/config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl restart hysteria-server.service",
      "systemctl enable hysteria-server.service",
    ]
  }

  provisioner "remote-exec" {
    when = destroy

    inline = [
      "systemctl stop hysteria-server.service || true",
      "rm -f /etc/hysteria/config.yaml",
    ]
  }
}
