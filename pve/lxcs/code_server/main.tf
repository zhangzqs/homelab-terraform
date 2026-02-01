resource "random_password" "container_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_password" "code_server_password" {
  count            = var.code_server_password == "" ? 1 : 0
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "container_key" {
  algorithm = "ED25519"
}

resource "terraform_data" "container_replacer" {
  triggers_replace = "2026-02-01 09:00" // 当这个字段发生改变,会触发依赖它的资源重新创建
}

resource "proxmox_virtual_environment_container" "code_server_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  description = "Code Server - VS Code in Browser"

  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = true # 非特权容器

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
    cores = 4
  }

  memory {
    dedicated = 4096
    swap      = 0
  }

  disk {
    datastore_id = "local-lvm"
    size         = 20
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.ubuntu_template_file_id
  }
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.code_server_container
  ]

  triggers = {
    vm_id      = proxmox_virtual_environment_container.code_server_container.id
    created_at = "2026-02-01 09:00"
    file_hash  = filesha256("${path.module}/scripts/setup.sh")
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup.sh"
    destination = "/tmp/setup.sh"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "5m"
    }

    inline = [
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh",
      "rm -f /tmp/setup.sh",
    ]
  }
}

locals {
  code_server_password = var.code_server_password != "" ? var.code_server_password : random_password.code_server_password[0].result

  code_server_config_content = templatefile("${path.module}/templates/config.yaml.tpl", {
    port        = var.code_server_port,
    password    = local.code_server_password,
    working_dir = var.working_dir,
  })

  code_server_service_content = templatefile("${path.module}/templates/code-server.service.tpl", {
    working_dir = var.working_dir,
  })
}

resource "null_resource" "setup_code_server_config" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    vm_id       = proxmox_virtual_environment_container.code_server_container.id
    config_hash = sha256(local.code_server_config_content)
  }

  provisioner "file" {
    content     = local.code_server_config_content
    destination = "${var.working_dir}/config.yaml"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }
}

resource "null_resource" "setup_systemd_service" {
  depends_on = [
    null_resource.setup_code_server_config
  ]

  triggers = {
    version      = 1
    vm_id        = proxmox_virtual_environment_container.code_server_container.id // 容器重建时重建 service
    config_hash  = sha256(local.code_server_config_content)                       // 配置变更时重启服务
    service_hash = sha256(local.code_server_service_content)                      // service 文件变更时重启服务
  }

  provisioner "file" {
    content     = local.code_server_service_content
    destination = "/etc/systemd/system/code-server.service"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }

    inline = [
      "mkdir -p ${var.working_dir}",
      "systemctl daemon-reload",
      "systemctl enable code-server.service",
      "systemctl restart code-server.service",
      "sleep 3",
      "systemctl status code-server.service --no-pager || true",
    ]
  }
}