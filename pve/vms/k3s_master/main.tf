// 虚拟机密码生成
resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

// 虚拟机 SSH 密钥对生成
resource "tls_private_key" "vm_key" {
  algorithm = "ED25519"
}

resource "terraform_data" "vm_replacer" {
  triggers_replace = 1 // 当这个字段发生改变，会触发依赖它的资源重新创建
}

# 创建 cloud-init 配置文件
resource "proxmox_virtual_environment_file" "cloud_init_config" {
  content_type = "snippets"
  datastore_id = var.cloud_init_config_datastore_id
  node_name    = var.pve_node_name

  source_raw {
    data = templatefile("${path.module}/templates/cloud-init-base.yaml.tpl", {
      root_password  = random_password.vm_password.result
      ssh_public_key = trimspace(tls_private_key.vm_key.public_key_openssh)
    })
    file_name = "cloud-init-k3s-master-${var.vm_id}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_master" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.vm_replacer
    ]
  }


  node_name   = var.pve_node_name
  vm_id       = var.vm_id
  name        = var.name
  description = "Terraform 自动创建的 K3s 虚拟机 (Master 节点)"
  tags        = ["k3s", "master", "terraform"]

  stop_on_destroy = true // 销毁虚拟机时先停止它
  started         = true // 创建后自动启动虚拟机
  on_boot         = true // 开机时自动启动虚拟机

  // 启动qemu agent, 资源创建完成将以agent是否在线为准
  agent {
    enabled = true
    timeout = "5m"
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
    floating  = var.memory_floating_enabled ? var.memory : 0
  }

  network_device {
    enabled = true
    bridge  = var.network_interface_bridge
    model   = "virtio"
  }

  disk {
    datastore_id = var.disk_datastore_id
    import_from  = var.ubuntu_cloud_image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${var.ipv4_address}/${var.ipv4_address_cidr}"
        gateway = var.ipv4_gateway
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.cloud_init_config.id
  }
}

resource "null_resource" "install_k3s_master" {
  depends_on = [proxmox_virtual_environment_vm.k3s_master]

  triggers = {
    version   = 1
    vm_res_id = proxmox_virtual_environment_vm.k3s_master.id
    file_hash = filesha256("${path.module}/scripts/install_k3s_master.sh")
  }

  provisioner "file" {
    source      = "${path.module}/scripts/install_k3s_master.sh"
    destination = "/tmp/install_k3s_master.sh"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "10m"
    }

    inline = [
      "chmod +x /tmp/install_k3s_master.sh",
      "/tmp/install_k3s_master.sh",
      "rm -f /tmp/install_k3s_master.sh"
    ]
  }
}

resource "null_resource" "configure_k3s_proxy" {
  depends_on = [null_resource.install_k3s_master]

  triggers = {
    version      = 1
    vm_res_id    = proxmox_virtual_environment_vm.k3s_master.id
    proxy_config = sha256(jsonencode(var.containerd_proxy))
  }

  provisioner "file" {
    content = templatefile("${path.module}/scripts/configure_k3s_proxy.sh.tpl", {
      has_proxy   = var.containerd_proxy != null
      http_proxy  = var.containerd_proxy != null ? var.containerd_proxy.http_proxy : ""
      https_proxy = var.containerd_proxy != null ? var.containerd_proxy.https_proxy : ""
      no_proxy    = var.containerd_proxy != null ? var.containerd_proxy.no_proxy : ""
    })
    destination = "/tmp/configure_k3s_proxy.sh"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "5m"
    }

    inline = [
      "chmod +x /tmp/configure_k3s_proxy.sh",
      "/tmp/configure_k3s_proxy.sh",
      "rm -f /tmp/configure_k3s_proxy.sh"
    ]
  }
}

# 动态管理 SSH 公钥
resource "null_resource" "manage_ssh_keys" {
  depends_on = [proxmox_virtual_environment_vm.k3s_master]

  triggers = {
    version        = 1
    vm_res_id      = proxmox_virtual_environment_vm.k3s_master.id
    ssh_keys_hash  = sha256(jsonencode(var.additional_ssh_keys))
    terraform_key  = sha256(tls_private_key.vm_key.public_key_openssh)
  }

  provisioner "file" {
    content = templatefile("${path.module}/scripts/manage_ssh_keys.sh.tpl", {
      terraform_key   = trimspace(tls_private_key.vm_key.public_key_openssh)
      additional_keys = var.additional_ssh_keys
    })
    destination = "/tmp/manage_ssh_keys.sh"

    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "5m"
    }

    inline = [
      "chmod +x /tmp/manage_ssh_keys.sh",
      "/tmp/manage_ssh_keys.sh",
      "rm -f /tmp/manage_ssh_keys.sh"
    ]
  }
}

# 获取 K3s kubeconfig
data "external" "kubeconfig" {
  depends_on = [null_resource.configure_k3s_proxy]

  program = [
    "bash",
    "${path.module}/scripts/get_kubeconfig.sh",
    tls_private_key.vm_key.private_key_openssh,
    var.ipv4_address
  ]
}
