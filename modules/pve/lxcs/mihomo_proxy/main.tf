resource "random_password" "container_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "tls_private_key" "container_key" {
  algorithm = "ED25519"
}

resource "terraform_data" "container_replacer" {
  triggers_replace = 1 # 当这个字段发生改变，会触发依赖它的资源重新创建
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

  // 透明代理网关需要 TUN 设备：
  // - features.nesting 一并打开（mihomo 启动时会触碰 cgroup）
  // - device_passthrough 透传宿主机 /dev/net/tun，并放行 cgroup deny-list
  // 注：bpg/proxmox 0.93 的 features 不支持 mknod；不过 /dev/net/tun
  // 已通过 device_passthrough 直接以节点形式投放到容器内，不需要 mknod
  features {
    nesting = true
  }

  device_passthrough {
    path = "/dev/net/tun"
    mode = "0666"
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

module "mihomo_deploy" {
  source = "../../../utils/mihomo_deploy"

  ssh_host        = var.ipv4_address
  ssh_user        = "root"
  ssh_private_key = tls_private_key.container_key.private_key_pem

  working_dir           = var.working_dir
  mihomo_config_content = var.mihomo_config_content

  # 容器重建时重新触发安装和配置
  extra_triggers = {
    container_id = proxmox_virtual_environment_container.mihomo_proxy_container.id
  }

  depends_on = [
    proxmox_virtual_environment_container.mihomo_proxy_container
  ]
}
