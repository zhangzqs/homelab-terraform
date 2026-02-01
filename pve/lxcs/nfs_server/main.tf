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

resource "proxmox_virtual_environment_container" "nfs_server_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  tags = ["terraform"]

  description = "NFS Server - 为 K3s 提供持久化存储"

  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = false # NFS服务器需要特权容器

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
    dedicated = 1024
    swap      = 0
  }

  disk {
    datastore_id = "local-lvm"
    size         = var.disk_size
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.ubuntu_template_file_id
  }

  # NFS服务器需要的特性
  features {
    nesting = true
  }
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.nfs_server_container
  ]

  triggers = {
    lxc_id    = proxmox_virtual_environment_container.nfs_server_container.id
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
  nfs_exports_content = "${var.nfs_export_path} ${var.nfs_allowed_network}(rw,sync,no_subtree_check,no_root_squash)"
}

resource "null_resource" "configure_nfs" {
  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    version        = 1
    lxc_id         = proxmox_virtual_environment_container.nfs_server_container.id
    exports_config = sha256(local.nfs_exports_content)
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
      "mkdir -p ${var.nfs_export_path}",
      "chmod 777 ${var.nfs_export_path}",
      "echo '${local.nfs_exports_content}' > /etc/exports",
      "exportfs -ra",
      "systemctl restart nfs-kernel-server",
      "sleep 2",
      "systemctl status nfs-kernel-server --no-pager || true",
      "showmount -e localhost || true",
    ]
  }
}
