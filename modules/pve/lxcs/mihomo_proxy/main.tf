resource "random_password" "container_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "container_key" {
  algorithm = "ED25519"
}

resource "terraform_data" "container_replacer" {
  triggers_replace = 1 // 当这个字段发生改变，会触发依赖它的资源重新创建
}

resource "proxmox_virtual_environment_container" "mihomo_proxy_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  tags = ["terraform"]

  description = "Mihomo 代理"

  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = true # 不需要特权容器

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
    cores = 2
  }
  memory {
    dedicated = 512
    swap      = 0
  }
  disk {
    datastore_id = "local-lvm"
    size         = 2
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.ubuntu_template_file_id
  }
}


resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.mihomo_proxy_container
  ]

  triggers = {
    lxc_id    = proxmox_virtual_environment_container.mihomo_proxy_container.id
    version   = 1
    file_hash = filesha256("${path.module}/scripts/setup.sh")
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup.sh"
    destination = "/tmp/setup.sh"

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
      "chmod +x /tmp/setup.sh",
      "/tmp/setup.sh",
      "rm -f /tmp/setup.sh",
    ]
  }
}

locals {
  mihomo_service_content = templatefile("${path.module}/templates/mihomo.service.tpl", {
    working_dir = var.working_dir,
  })
}

resource "null_resource" "setup_systemd_service" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    version      = 1
    service_hash = sha256(local.mihomo_service_content)
  }

  provisioner "file" {
    content     = local.mihomo_service_content
    destination = "/etc/systemd/system/mihomo.service"

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
      "systemctl enable mihomo.service",
    ]
  }
}

resource "null_resource" "update_mihomo_config" {
  depends_on = [
    null_resource.setup_systemd_service
  ]

  triggers = {
    version     = 1
    config_hash = sha256(var.mihomo_config_content)
  }

  provisioner "file" {
    content     = var.mihomo_config_content
    destination = "${var.working_dir}/config.yaml"

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
      "systemctl restart mihomo.service",
      "sleep 2",
      "systemctl status mihomo.service --no-pager || true",
    ]
  }
}
