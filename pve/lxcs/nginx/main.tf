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

resource "proxmox_virtual_environment_container" "nginx_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  tags = ["terraform"]

  description = "Nginx 反向代理"

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

# 安装和配置Nginx
resource "null_resource" "setup_nginx" {
  depends_on = [
    proxmox_virtual_environment_container.nginx_container
  ]

  triggers = {
    lxc_id    = proxmox_virtual_environment_container.nginx_container.id
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

# 配置systemd服务
resource "null_resource" "setup_systemd_service" {
  depends_on = [
    null_resource.setup_nginx
  ]

  triggers = {
    version      = 1
    service_hash = filesha256("${path.module}/templates/nginx.service.tpl")
  }

  provisioner "file" {
    source      = "${path.module}/templates/nginx.service.tpl"
    destination = "/etc/systemd/system/nginx.service"

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
      "systemctl daemon-reload",
      "systemctl enable nginx.service",
    ]
  }
}

# 部署Nginx配置文件
resource "null_resource" "deploy_nginx_configs" {
  depends_on = [
    null_resource.setup_systemd_service
  ]

  triggers = {
    version     = 1
    config_hash = sha256(jsonencode(var.nginx_configs))
  }

  # 上传nginx.conf
  provisioner "file" {
    content     = var.nginx_configs["nginx.conf"]
    destination = "/root/nginx/config/nginx.conf"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }

  # 上传upstream.conf
  provisioner "file" {
    content     = var.nginx_configs["conf.d/upstream.conf"]
    destination = "/root/nginx/config/conf.d/upstream.conf"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }

  # 上传servers.conf
  provisioner "file" {
    content     = var.nginx_configs["conf.d/servers.conf"]
    destination = "/root/nginx/config/conf.d/servers.conf"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }

  # 测试配置并重启服务
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }

    inline = [
      "nginx -t -c /root/nginx/config/nginx.conf",
      "systemctl restart nginx.service",
      "sleep 2",
      "systemctl status nginx.service --no-pager || true",
    ]
  }
}
