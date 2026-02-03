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

resource "proxmox_virtual_environment_container" "tailscale_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  tags = ["terraform", "tailscale"]

  description = "Tailscale子网路由器"

  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = true # 非特权容器

  # 关键配置：允许TUN设备访问
  # Tailscale需要 /dev/net/tun 设备才能正常工作
  features {
    nesting = true # 启用嵌套容器支持
    keyctl  = true # 启用keyctl系统调用
  }

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
    cores = 1
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

  # 直通 /dev/net/tun 设备
  # Tailscale需要 /dev/net/tun 设备才能正常工作
  # 参考: https://tailscale.com/kb/1130/lxc
  device_passthrough {
    path = "/dev/net/tun"
  }
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.tailscale_container
  ]

  triggers = {
    version    = 1
    res_lxc_id = proxmox_virtual_environment_container.tailscale_container.id
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
  tailscaled_service_content = file("${path.module}/files/tailscaled.service")

  tailscale_web_service_content = var.metrics_enabled ? templatefile("${path.module}/templates/tailscale-web.service.tpl", {
    metrics_port = var.metrics_port
  }) : null

  connect_tailscale_script = templatefile("${path.module}/templates/connect_tailscale.sh.tpl", {
    auth_key         = var.tailscale_auth_key
    hostname         = var.tailscale_hostname
    advertise_routes = var.tailscale_advertise_routes
    accept_routes    = var.tailscale_accept_routes
    exit_node        = var.tailscale_exit_node
    ssh_enabled      = var.tailscale_ssh_enabled
    metrics_enabled  = var.metrics_enabled
    metrics_port     = var.metrics_port
    ipv4_address     = var.ipv4_address
  })
}

resource "null_resource" "setup_tailscale_service" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    version            = 1
    setup_container_id = null_resource.setup_container.id
    service_hash       = sha256(local.tailscaled_service_content)
    script_hash        = filesha256("${path.module}/scripts/setup_tailscale_service.sh")
  }

  provisioner "file" {
    content     = local.tailscaled_service_content
    destination = "/tmp/tailscaled.service"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup_tailscale_service.sh"
    destination = "/tmp/setup_tailscale_service.sh"

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
      "chmod +x /tmp/setup_tailscale_service.sh",
      "/tmp/setup_tailscale_service.sh",
      "rm -f /tmp/setup_tailscale_service.sh",
    ]
  }
}

resource "null_resource" "setup_tailscale_web_service" {
  count = var.metrics_enabled ? 1 : 0

  depends_on = [
    null_resource.setup_tailscale_service
  ]

  triggers = {
    version                    = 1
    setup_tailscale_service_id = null_resource.setup_tailscale_service.id
    service_hash               = sha256(local.tailscale_web_service_content)
    script_hash                = filesha256("${path.module}/scripts/setup_tailscale_web.sh")
  }

  provisioner "file" {
    content     = local.tailscale_web_service_content
    destination = "/tmp/tailscale-web.service"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }

  provisioner "file" {
    source      = "${path.module}/scripts/setup_tailscale_web.sh"
    destination = "/tmp/setup_tailscale_web.sh"

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
      "chmod +x /tmp/setup_tailscale_web.sh",
      "/tmp/setup_tailscale_web.sh",
      "rm -f /tmp/setup_tailscale_web.sh",
    ]
  }
}

resource "null_resource" "connect_tailscale" {
  depends_on = [
    null_resource.setup_tailscale_service,
    null_resource.setup_tailscale_web_service
  ]

  triggers = {
    version                    = 1
    setup_tailscale_service_id = null_resource.setup_tailscale_service.id
    script_hash                = sha256(local.connect_tailscale_script)
  }

  provisioner "file" {
    content     = local.connect_tailscale_script
    destination = "/tmp/connect_tailscale.sh"

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
      "chmod +x /tmp/connect_tailscale.sh",
      "/tmp/connect_tailscale.sh",
      "rm -f /tmp/connect_tailscale.sh",
    ]
  }
}
