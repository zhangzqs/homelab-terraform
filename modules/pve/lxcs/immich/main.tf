resource "random_password" "container_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "db_password" {
  length  = 24
  special = false
}

resource "tls_private_key" "container_key" {
  algorithm = "ED25519"
}

resource "terraform_data" "container_replacer" {
  triggers_replace = 1
}

resource "proxmox_virtual_environment_container" "immich_container" {
  lifecycle {
    replace_triggered_by = [terraform_data.container_replacer]
  }

  tags          = ["terraform"]
  description   = "Immich Photo Service"
  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = true

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "${var.ipv4_address}/${var.ipv4_address_cidr}"
        gateway = var.ipv4_gateway
      }
    }

    user_account {
      keys = [
        trimspace(tls_private_key.container_key.public_key_openssh)
      ]
      password = random_password.container_password.result
    }
  }

  network_interface {
    name   = "eth0"
    bridge = var.network_interface_bridge
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_dedicated
    swap      = 0
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.disk_size
  }

  dynamic "mount_point" {
    for_each = var.host_mount_points
    content {
      volume    = mount_point.value.host_path
      path      = mount_point.value.container_path
      read_only = mount_point.value.read_only != null ? mount_point.value.read_only : false
      shared    = mount_point.value.shared != null ? mount_point.value.shared : false
      backup    = mount_point.value.backup != null ? mount_point.value.backup : false
    }
  }

  features {
    nesting = true
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.ubuntu_template_file_id
  }
}

locals {
  docker_compose_content = templatefile("${path.module}/templates/docker-compose.yml.tpl", {
    immich_port = var.immich_port
  })
  immich_env_content = templatefile("${path.module}/templates/immich.env.tpl", {
    upload_location  = var.upload_location
    db_data_location = var.db_data_location
    timezone         = var.timezone
    immich_version   = var.immich_version
    db_password      = random_password.db_password.result
  })
  setup_container_command = var.install_proxy != null ? join(" ", [
    "DOCKER_SETUP_HTTP_PROXY=${var.install_proxy.http_proxy}",
    "DOCKER_SETUP_HTTPS_PROXY=${var.install_proxy.https_proxy}",
    "/tmp/setup.sh",
  ]) : "/tmp/setup.sh"
  backup_script_content = var.backup_target_dir != null ? templatefile("${path.module}/templates/backup.sh.tpl", {
    upload_location  = var.upload_location
    db_data_location = var.db_data_location
    backup_target_dir = var.backup_target_dir
  }) : ""
  mirror_script_content = var.mirror_target_dir != null ? templatefile("${path.module}/templates/mirror.sh.tpl", {
    upload_location  = var.upload_location
    db_data_location = var.db_data_location
    mirror_target_dir = var.mirror_target_dir
  }) : ""
  backup_cron_content = var.backup_target_dir != null ? join("\n", [
    "SHELL=/bin/bash",
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "${var.backup_schedule} root /usr/local/bin/immich-backup.sh >> /var/log/immich-backup.log 2>&1",
    "",
  ]) : ""
  mirror_cron_content = var.mirror_target_dir != null ? join("\n", [
    "SHELL=/bin/bash",
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
    "${var.mirror_schedule} root /usr/local/bin/immich-mirror.sh >> /var/log/immich-mirror.log 2>&1",
    "",
  ]) : ""
  configure_docker_proxy_script = join("\n", var.install_proxy != null ? [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "mkdir -p /etc/systemd/system/docker.service.d",
    "cat > /etc/systemd/system/docker.service.d/http-proxy.conf <<'EOF'",
    "[Service]",
    "Environment=\"HTTP_PROXY=${var.install_proxy.http_proxy}\"",
    "Environment=\"HTTPS_PROXY=${var.install_proxy.https_proxy}\"",
    "EOF",
    "systemctl daemon-reload",
    "systemctl restart docker",
    ] : [
    "#!/usr/bin/env bash",
    "set -euo pipefail",
    "rm -f /etc/systemd/system/docker.service.d/http-proxy.conf",
    "systemctl daemon-reload",
    "systemctl restart docker",
  ])
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.immich_container
  ]

  triggers = {
    res_vm_id   = proxmox_virtual_environment_container.immich_container.id
    version     = 1
    file_hash   = filesha256("${path.module}/scripts/setup.sh")
    host        = var.ipv4_address
    working_dir = var.working_dir
    proxy_config = sha256(jsonencode(var.install_proxy))
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      local.setup_container_command,
      "rm -f /tmp/setup.sh",
    ]
  }
}

resource "null_resource" "deploy_immich" {
  depends_on = [
    null_resource.configure_docker_proxy
  ]

  triggers = {
    res_vm_id           = proxmox_virtual_environment_container.immich_container.id
    docker_compose_hash = sha256(local.docker_compose_content)
    immich_env_hash     = sha256(local.immich_env_content)
    working_dir         = var.working_dir
    upload_location     = var.upload_location
    db_data_location    = var.db_data_location
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.working_dir}",
      "mkdir -p ${var.upload_location}",
      "mkdir -p ${var.db_data_location}",
    ]
  }

  provisioner "file" {
    content     = local.immich_env_content
    destination = "${var.working_dir}/.env"
  }

  provisioner "file" {
    content     = local.docker_compose_content
    destination = "${var.working_dir}/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${var.working_dir} && docker compose up -d",
      "cd ${var.working_dir} && docker compose ps",
    ]
  }
}

resource "null_resource" "configure_docker_proxy" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    res_vm_id         = proxmox_virtual_environment_container.immich_container.id
    docker_proxy_hash = sha256(local.configure_docker_proxy_script)
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    content     = local.configure_docker_proxy_script
    destination = "/tmp/configure-docker-proxy.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/configure-docker-proxy.sh",
      "/tmp/configure-docker-proxy.sh",
      "rm -f /tmp/configure-docker-proxy.sh",
    ]
  }
}

resource "null_resource" "configure_backup" {
  count = var.backup_target_dir != null ? 1 : 0

  depends_on = [
    null_resource.deploy_immich
  ]

  triggers = {
    res_vm_id         = proxmox_virtual_environment_container.immich_container.id
    backup_script_hash = sha256(local.backup_script_content)
    backup_cron_hash   = sha256(local.backup_cron_content)
    backup_target_dir  = var.backup_target_dir
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    content     = local.backup_script_content
    destination = "/usr/local/bin/immich-backup.sh"
  }

  provisioner "file" {
    content     = local.backup_cron_content
    destination = "/etc/cron.d/immich-backup"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /usr/local/bin/immich-backup.sh",
      "chmod 0644 /etc/cron.d/immich-backup",
      "mkdir -p ${var.backup_target_dir}/immich_data",
      "mkdir -p ${var.backup_target_dir}/immich_postgres_data",
      "/usr/local/bin/immich-backup.sh",
      "systemctl restart cron",
    ]
  }
}

resource "null_resource" "configure_mirror" {
  count = var.mirror_target_dir != null ? 1 : 0

  depends_on = [
    null_resource.deploy_immich
  ]

  triggers = {
    res_vm_id         = proxmox_virtual_environment_container.immich_container.id
    mirror_script_hash = sha256(local.mirror_script_content)
    mirror_cron_hash   = sha256(local.mirror_cron_content)
    mirror_target_dir  = var.mirror_target_dir
  }

  connection {
    type        = "ssh"
    user        = "root"
    host        = var.ipv4_address
    private_key = tls_private_key.container_key.private_key_pem
    timeout     = "5m"
  }

  provisioner "file" {
    content     = local.mirror_script_content
    destination = "/usr/local/bin/immich-mirror.sh"
  }

  provisioner "file" {
    content     = local.mirror_cron_content
    destination = "/etc/cron.d/immich-mirror"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /usr/local/bin/immich-mirror.sh",
      "chmod 0644 /etc/cron.d/immich-mirror",
      "mkdir -p ${var.mirror_target_dir}/immich_data",
      "mkdir -p ${var.mirror_target_dir}/immich_postgres_data",
      "/usr/local/bin/immich-mirror.sh",
      "systemctl restart cron",
    ]
  }
}
