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

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.vm_key.private_key_pem
      timeout     = "5m"
    }

    inline = var.containerd_proxy != null ? [
      # 有代理配置：上传配置文件
      "cat > /etc/systemd/system/k3s.service.env <<'EOF'",
      "CONTAINERD_HTTP_PROXY=${var.containerd_proxy.http_proxy}",
      "CONTAINERD_HTTPS_PROXY=${var.containerd_proxy.https_proxy}",
      "CONTAINERD_NO_PROXY=${var.containerd_proxy.no_proxy}",
      "EOF",
      "systemctl daemon-reload",
      "systemctl restart k3s",
      "sleep 5",
      "systemctl status k3s --no-pager || true",
      ] : [
      # 无代理配置：删除配置文件
      "rm -f /etc/systemd/system/k3s.service.env",
      "systemctl daemon-reload",
      "systemctl restart k3s",
      "sleep 5",
      "systemctl status k3s --no-pager || true",
    ]
  }
}

# 获取 K3s kubeconfig
data "external" "kubeconfig" {
  depends_on = [null_resource.configure_k3s_proxy]

  program = ["bash", "-c", <<-EOT
    set -e

    # 创建临时 SSH 密钥文件
    SSH_KEY_FILE=$(mktemp)
    trap "rm -f $SSH_KEY_FILE" EXIT

    echo '${tls_private_key.vm_key.private_key_openssh}' > $SSH_KEY_FILE
    chmod 600 $SSH_KEY_FILE

    # 通过 SSH 获取 kubeconfig
    KUBECONFIG_CONTENT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -i $SSH_KEY_FILE root@${var.ipv4_address} \
      "cat /etc/rancher/k3s/k3s.yaml" 2>/dev/null)

    # 替换 IP 地址
    KUBECONFIG_CONTENT=$(echo "$KUBECONFIG_CONTENT" | sed 's/127.0.0.1/${var.ipv4_address}/g')

    # 使用 Python 输出 JSON（大多数系统都有 Python）
    python3 -c "import json; print(json.dumps({'kubeconfig': '''$KUBECONFIG_CONTENT'''}))"
  EOT
  ]
}
