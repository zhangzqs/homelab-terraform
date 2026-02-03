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

resource "proxmox_virtual_environment_container" "coredns_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  tags = ["terraform"]

  description = "CoreDNS DNS服务器"

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
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.coredns_container
  ]

  triggers = {
    version   = 1
    lxc_id    = proxmox_virtual_environment_container.coredns_container.id
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
  corefile_content = templatefile("${path.module}/templates/Corefile.tpl", {
    metrics_port         = var.metrics_port
    cache_ttl            = var.cache_ttl
    cache_prefetch       = var.cache_prefetch
    cache_serve_stale    = var.cache_serve_stale
    enable_dnssec        = var.enable_dnssec
    hosts                = var.hosts
    wildcard_domains     = var.wildcard_domains
    upstream_dns_servers = var.upstream_dns_servers
    working_dir          = var.working_dir
  })

  coredns_service_content = templatefile("${path.module}/templates/coredns.service.tpl", {
    working_dir = var.working_dir
    dns_port    = var.dns_port
  })
}

resource "null_resource" "setup_systemd_service" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    version            = 1
    setup_container_id = null_resource.setup_container.id
    service_hash       = sha256(local.coredns_service_content)
  }

  provisioner "file" {
    content     = local.coredns_service_content
    destination = "/etc/systemd/system/coredns.service"

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
      "systemctl enable coredns.service",
    ]
  }
}

resource "null_resource" "update_coredns_config" {
  depends_on = [
    null_resource.setup_systemd_service
  ]

  triggers = {
    version                  = 1
    setup_systemd_service_id = null_resource.setup_systemd_service.id
    config_hash              = sha256(local.corefile_content)
  }

  provisioner "file" {
    content     = local.corefile_content
    destination = "${var.working_dir}/Corefile"

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
      "systemctl restart coredns.service",
      "sleep 2",
      "systemctl status coredns.service --no-pager || true",
    ]
  }
}
