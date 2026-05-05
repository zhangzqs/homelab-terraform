locals {
  resolved_ssh_private_key = var.ssh_private_key != null ? (
    fileexists(var.ssh_private_key) ? file(var.ssh_private_key) : var.ssh_private_key
    ) : (
    var.ssh_private_key_path != null ? file(var.ssh_private_key_path) : null
  )

  script_prefix = "/tmp/node_exporter_host_${md5("${var.ssh_host}:${var.listen_address}:${var.listen_port}")}"

  setup_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    export DEBIAN_FRONTEND=noninteractive
    LISTEN_ADDRESS=${jsonencode(var.listen_address)}
    LISTEN_PORT=${var.listen_port}

    if ! command -v prometheus-node-exporter >/dev/null 2>&1; then
      DISABLED_APT_DIR=$(mktemp -d)
      cleanup_apt_sources() {
        if [ -f /etc/apt/sources.list.node-exporter-host.bak ]; then
          mv /etc/apt/sources.list.node-exporter-host.bak /etc/apt/sources.list
        fi

        for file in "$DISABLED_APT_DIR"/*; do
          [ -e "$file" ] || continue
          mv "$file" "/etc/apt/sources.list.d/$(basename "$file" .disabled)"
        done

        rm -rf "$DISABLED_APT_DIR"
      }
      trap cleanup_apt_sources EXIT

      if [ -f /etc/apt/sources.list ] && grep -q 'enterprise.proxmox.com' /etc/apt/sources.list; then
        cp /etc/apt/sources.list /etc/apt/sources.list.node-exporter-host.bak
        sed '/enterprise\\.proxmox\\.com/s/^/# disabled by node_exporter_host /' /etc/apt/sources.list.node-exporter-host.bak > /etc/apt/sources.list
      fi

      for file in /etc/apt/sources.list.d/*; do
        [ -f "$file" ] || continue
        if grep -q 'enterprise.proxmox.com' "$file"; then
          mv "$file" "$DISABLED_APT_DIR/$(basename "$file").disabled"
        fi
      done

      apt-get update
      apt-get install -y prometheus-node-exporter
    fi

    if command -v podman >/dev/null 2>&1; then
      podman rm -f ${jsonencode(var.container_name)} >/dev/null 2>&1 || true
    fi

    mkdir -p /etc/systemd/system/prometheus-node-exporter.service.d
    cat >/etc/systemd/system/prometheus-node-exporter.service.d/override.conf <<EOF
    [Service]
    ExecStart=
    ExecStart=/usr/bin/prometheus-node-exporter --web.listen-address=$${LISTEN_ADDRESS}:$${LISTEN_PORT}
    EOF

    systemctl daemon-reload
    systemctl enable --now prometheus-node-exporter
    systemctl restart prometheus-node-exporter
    sleep 3
    systemctl is-active --quiet prometheus-node-exporter
    ss -lnt | grep -q "$${LISTEN_ADDRESS}:$${LISTEN_PORT}"
  EOT
}

resource "null_resource" "node_exporter_host" {
  triggers = {
    script_hash     = sha256(local.setup_script)
    script_prefix   = local.script_prefix
    ssh_host        = var.ssh_host
    ssh_port        = var.ssh_port
    ssh_user        = var.ssh_user
    ssh_password    = var.ssh_password
    ssh_private_key = local.resolved_ssh_private_key
    listen_address  = var.listen_address
    listen_port     = var.listen_port
    container_name  = var.container_name
  }

  lifecycle {
    precondition {
      condition = (
        var.ssh_password != null ||
        var.ssh_private_key != null ||
        var.ssh_private_key_path != null
      )
      error_message = "至少需要配置一种 SSH 认证方式（ssh_password、ssh_private_key 或 ssh_private_key_path）"
    }
  }

  connection {
    type        = "ssh"
    host        = self.triggers.ssh_host
    port        = self.triggers.ssh_port
    user        = self.triggers.ssh_user
    password    = self.triggers.ssh_password
    private_key = self.triggers.ssh_private_key
  }

  provisioner "file" {
    content     = local.setup_script
    destination = "${local.script_prefix}.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 ${local.script_prefix}.sh",
      "${local.script_prefix}.sh",
      "rm -f ${local.script_prefix}.sh",
    ]
  }

  provisioner "remote-exec" {
    when = destroy

    inline = [
      "if command -v podman >/dev/null 2>&1; then podman rm -f ${self.triggers.container_name} >/dev/null 2>&1 || true; fi",
      "if command -v systemctl >/dev/null 2>&1; then systemctl disable --now prometheus-node-exporter >/dev/null 2>&1 || true; fi",
      "apt-get remove -y prometheus-node-exporter >/dev/null 2>&1 || true",
      "rm -rf /etc/systemd/system/prometheus-node-exporter.service.d",
      "systemctl daemon-reload >/dev/null 2>&1 || true",
    ]
  }
}
