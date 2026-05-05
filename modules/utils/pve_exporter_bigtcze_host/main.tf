locals {
  resolved_ssh_private_key = var.ssh_private_key != null ? (
    fileexists(var.ssh_private_key) ? file(var.ssh_private_key) : var.ssh_private_key
    ) : (
    var.ssh_private_key_path != null ? file(var.ssh_private_key_path) : null
  )

  script_prefix = "/tmp/pve_exporter_bigtcze_host_${md5("${var.ssh_host}:${var.listen_address}:${var.listen_port}")}"

  setup_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    # Keep setup idempotent so replacements can converge without destructive teardown.
    export DEBIAN_FRONTEND=noninteractive

    LISTEN_ADDRESS=${jsonencode(var.listen_address)}
    LISTEN_PORT=${var.listen_port}
    PVE_HOST=${jsonencode(var.pve_host)}
    PVE_PORT=${var.pve_port}
    PVE_USER=${jsonencode(var.pve_user)}
    PVE_PASSWORD=${jsonencode(var.pve_password)}
    PVE_INSECURE_SKIP_VERIFY=${var.pve_verify_ssl ? "false" : "true"}
    DOWNLOAD_VERSION=${jsonencode(var.exporter_version)}
    DOWNLOAD_SHA256=${jsonencode(var.exporter_sha256)}
    BINARY_PATH="/usr/local/bin/pve-exporter"
    CONFIG_DIR="/etc/pve-exporter"
    CONFIG_PATH="$${CONFIG_DIR}/config.yml"
    SERVICE_PATH="/etc/systemd/system/pve-exporter.service"
    DOWNLOAD_URL="https://github.com/bigtcze/pve-exporter/releases/download/v$${DOWNLOAD_VERSION}/pve-exporter-linux-amd64"
    DISABLED_APT_DIR="$(mktemp -d)"
    TMP_BINARY="$(mktemp)"

    cleanup_apt_sources() {
      if [ -f /etc/apt/sources.list.pve-exporter-bigtcze-host.bak ]; then
        mv /etc/apt/sources.list.pve-exporter-bigtcze-host.bak /etc/apt/sources.list
      fi

      for file in "$${DISABLED_APT_DIR}"/*; do
        [ -e "$${file}" ] || continue
        mv "$${file}" "/etc/apt/sources.list.d/$(basename "$${file}" .disabled)"
      done
    }

    cleanup() {
      rm -f "$${TMP_BINARY}"
      cleanup_apt_sources
      rm -rf "$${DISABLED_APT_DIR}"
    }

    trap cleanup EXIT

    if ! command -v curl >/dev/null 2>&1; then
      if [ -f /etc/apt/sources.list ] && grep -q 'enterprise.proxmox.com' /etc/apt/sources.list; then
        cp /etc/apt/sources.list /etc/apt/sources.list.pve-exporter-bigtcze-host.bak
        sed '/enterprise\\.proxmox\\.com/s/^/# disabled by pve_exporter_bigtcze_host /' /etc/apt/sources.list.pve-exporter-bigtcze-host.bak > /etc/apt/sources.list
      fi

      for file in /etc/apt/sources.list.d/*; do
        [ -f "$${file}" ] || continue
        if grep -q 'enterprise.proxmox.com' "$${file}"; then
          mv "$${file}" "$${DISABLED_APT_DIR}/$(basename "$${file}").disabled"
        fi
      done

      apt-get update
      apt-get install -y curl ca-certificates
    fi

    if command -v podman >/dev/null 2>&1; then
      podman rm -f pve-exporter-bigtcze >/dev/null 2>&1 || true
    fi

    if ! id -u pve-exporter >/dev/null 2>&1; then
      useradd --system --no-create-home --shell /usr/sbin/nologin pve-exporter
    fi

    mkdir -p /etc/pve-exporter
    install -d -o root -g pve-exporter -m 750 "$${CONFIG_DIR}"

    curl -fsSL -o "$${TMP_BINARY}" "$${DOWNLOAD_URL}"
    printf '%s  %s\n' "$${DOWNLOAD_SHA256}" "$${TMP_BINARY}" | sha256sum -c -
    install -m 755 "$${TMP_BINARY}" "$${BINARY_PATH}"

    cat >"$${CONFIG_PATH}" <<EOF
    proxmox:
      host: "$${PVE_HOST}"
      port: $${PVE_PORT}
      user: "$${PVE_USER}"
      password: "$${PVE_PASSWORD}"
      insecure_skip_verify: $${PVE_INSECURE_SKIP_VERIFY}

    server:
      listen_address: "$${LISTEN_ADDRESS}:$${LISTEN_PORT}"
      metrics_path: "/metrics"
    EOF

    chown root:pve-exporter "$${CONFIG_PATH}"
    chmod 640 "$${CONFIG_PATH}"

    cat >"$${SERVICE_PATH}" <<'EOF'
    [Unit]
    Description=Proxmox VE Exporter for Prometheus
    Documentation=https://github.com/bigtcze/pve-exporter
    After=network-online.target
    Wants=network-online.target

    [Service]
    Type=simple
    User=pve-exporter
    Group=pve-exporter
    ExecStart=/usr/local/bin/pve-exporter -config /etc/pve-exporter/config.yml
    Restart=on-failure
    RestartSec=5

    ProtectSystem=strict
    ProtectHome=yes
    PrivateTmp=yes
    ProtectKernelTunables=yes
    ProtectKernelModules=yes
    ProtectControlGroups=yes
    ReadOnlyPaths=/
    ReadWritePaths=

    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl enable --now pve-exporter
    systemctl restart pve-exporter
  EOT

  verify_script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    LISTEN_ADDRESS=${jsonencode(var.listen_address)}
    LISTEN_PORT=${var.listen_port}

    for _ in $(seq 1 30); do
      if systemctl is-active --quiet pve-exporter; then
        metrics="$(curl -fsS --max-time 20 "http://$${LISTEN_ADDRESS}:$${LISTEN_PORT}/metrics")"
        if grep -q '^pve_' <<<"$${metrics}"; then
          exit 0
        fi
      fi

      sleep 2
    done

    systemctl status pve-exporter --no-pager || true
    journalctl -u pve-exporter -n 50 --no-pager || true
    exit 1
  EOT
}

resource "null_resource" "pve_exporter_bigtcze_host" {
  triggers = {
    setup_script_hash  = sha256(local.setup_script)
    verify_script_hash = sha256(local.verify_script)
    script_prefix      = local.script_prefix
    ssh_host           = var.ssh_host
    ssh_port           = var.ssh_port
    ssh_user           = var.ssh_user
    ssh_password       = var.ssh_password
    ssh_private_key    = local.resolved_ssh_private_key
    listen_address     = var.listen_address
    listen_port        = var.listen_port
    pve_host           = var.pve_host
    pve_port           = var.pve_port
    pve_user           = var.pve_user
    pve_password       = var.pve_password
    pve_verify_ssl     = tostring(var.pve_verify_ssl)
    exporter_version   = var.exporter_version
    exporter_sha256    = var.exporter_sha256
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
    destination = "${local.script_prefix}.setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 ${local.script_prefix}.setup.sh",
      "${local.script_prefix}.setup.sh",
      "rm -f ${local.script_prefix}.setup.sh",
    ]
  }

  provisioner "file" {
    content     = local.verify_script
    destination = "${local.script_prefix}.verify.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 700 ${local.script_prefix}.verify.sh",
      "${local.script_prefix}.verify.sh",
      "rm -f ${local.script_prefix}.verify.sh",
    ]
  }

}
