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
locals {
  nginx_service_content = templatefile("${path.module}/templates/nginx.service.tpl", {
    working_dir = var.working_dir
  })

  setup_systemd_service_command = [
    "mkdir -p ${var.working_dir}/conf.d",
    "mkdir -p ${var.working_dir}/logs",
    "mkdir -p ${var.working_dir}/cache/proxy",
    "mkdir -p ${var.working_dir}/ssl",
    "chmod 755 ${var.working_dir}",
    "chmod 755 ${var.working_dir}/conf.d",
    "chmod 755 ${var.working_dir}/logs",
    "chmod 755 ${var.working_dir}/cache",
    "chmod 755 ${var.working_dir}/ssl",
    "systemctl daemon-reload",
    "systemctl enable nginx.service",
  ]
}

resource "null_resource" "setup_systemd_service" {
  depends_on = [
    null_resource.setup_nginx
  ]

  triggers = {
    version      = 1
    service_hash = sha256(local.nginx_service_content)
    command_hash = sha256(join("", local.setup_systemd_service_command))
  }

  provisioner "file" {
    content     = local.nginx_service_content
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

    inline = local.setup_systemd_service_command
  }
}

# 部署Nginx配置文件
resource "null_resource" "deploy_nginx_configs" {
  for_each = var.nginx_configs

  depends_on = [
    null_resource.setup_systemd_service
  ]

  triggers = {
    version     = 2
    config_hash = sha256(each.value)
  }

  provisioner "file" {
    content     = each.value
    destination = "${var.working_dir}/${each.key}"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "2m"
    }
  }
}

# 测试配置并重启Nginx服务
resource "null_resource" "restart_nginx" {
  depends_on = [
    null_resource.deploy_nginx_configs
  ]

  triggers = {
    version     = 1
    config_hash = sha256(jsonencode(var.nginx_configs))
    before_step_ids = join(",", [
      for r in null_resource.deploy_nginx_configs :
      r.id
    ])
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
      "nginx -t -c ${var.working_dir}/nginx.conf",
      "systemctl restart nginx.service",
      "sleep 2",
      "systemctl status nginx.service --no-pager || true",
    ]
  }
}
