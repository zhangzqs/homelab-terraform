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

resource "null_resource" "storage_server_container_protect" {
  count = var.prevent_container_destroy ? 1 : 0

  triggers = {
    storage_server_container_id = proxmox_virtual_environment_container.storage_server_container.id
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "proxmox_virtual_environment_container" "storage_server_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
  }

  tags = ["terraform"]

  description = "通用存储服务器 - 支持 NFS/SMB 等协议"

  node_name     = var.pve_node_name
  vm_id         = var.vm_id
  started       = true
  start_on_boot = true
  unprivileged  = false # 存储服务器需要特权容器

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
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_dedicated
    swap      = var.memory_swap
  }

  disk {
    datastore_id = var.disk_datastore_id
    size         = var.disk_size
  }

  # 动态挂载宿主机目录
  dynamic "mount_point" {
    for_each = var.host_mount_points
    content {
      volume    = mount_point.value.host_path
      path      = mount_point.value.container_path
      read_only = mount_point.value.read_only != null ? mount_point.value.read_only : false
      shared    = mount_point.value.shared != null ? mount_point.value.shared : false
      backup    = mount_point.value.backup != null ? mount_point.value.backup : false
    }
  }

  operating_system {
    type             = "ubuntu"
    template_file_id = var.ubuntu_template_file_id
  }

  # 存储服务器需要的特性
  features {
    nesting = true
  }
}

resource "null_resource" "setup_container" {
  depends_on = [
    proxmox_virtual_environment_container.storage_server_container
  ]

  triggers = {
    lxc_id            = proxmox_virtual_environment_container.storage_server_container.id
    version           = 1
    file_hash         = filesha256("${path.module}/scripts/setup.sh")
    enabled_protocols = join(",", sort(var.enabled_protocols))
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
      "/tmp/setup.sh ${join(" ", var.enabled_protocols)}",
      "rm -f /tmp/setup.sh",
    ]
  }
}

locals {
  # 收集所有宿主机挂载点的容器路径
  mounted_paths = toset([for mp in var.host_mount_points : mp.container_path])

  # 生成 NFS exports 内容
  nfs_exports_lines = [
    for export in var.nfs_exports :
    "${export.path} ${export.allowed_network}(${export.options != null ? export.options : "rw,sync,no_subtree_check,no_root_squash"})"
  ]
  nfs_exports_content = join("\n", local.nfs_exports_lines)

  # 生成 NFS 目录创建命令（跳过已挂载的目录）
  nfs_mkdir_commands = [
    for export in var.nfs_exports :
    "if ! mountpoint -q ${export.path} 2>/dev/null; then mkdir -p ${export.path} && chmod 755 ${export.path}; fi"
    if !contains(local.mounted_paths, export.path)
  ]

  # 生成 SMB 环境变量（dockur/samba 单用户模式）
  smb_env_vars = {
    USER = var.smb_user.username
    PASS = var.smb_user.password
  }

  # 生成 SMB 配置文件
  smb_config = templatefile("${path.module}/templates/smb.conf.tftpl", {
    username = var.smb_user.username
    shares   = var.smb_shares
  })

  # 生成 SMB 目录创建命令
  smb_mkdir_commands = [
    for share in var.smb_shares :
    "if ! mountpoint -q ${share.path} 2>/dev/null; then mkdir -p ${share.path} && chmod 755 ${share.path}; fi"
    if !contains(local.mounted_paths, share.path)
  ]
}

# NFS 配置
resource "null_resource" "configure_nfs" {
  count = contains(var.enabled_protocols, "nfs") ? 1 : 0

  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    version        = 2
    lxc_id         = proxmox_virtual_environment_container.storage_server_container.id
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

    inline = concat(
      local.nfs_mkdir_commands,
      [
        <<-EOT
        cat > /etc/exports <<'NFSEOF'
        ${local.nfs_exports_content}
        NFSEOF
        EOT
        ,
        "exportfs -ra",
        "systemctl restart nfs-kernel-server",
        "sleep 2",
        "systemctl status nfs-kernel-server --no-pager || true",
        "showmount -e localhost || true",
      ]
    )
  }
}

# SMB 配置（使用 Podman 运行 dockur/samba 容器）
resource "null_resource" "prepare_smb_dirs" {
  count = contains(var.enabled_protocols, "smb") ? 1 : 0

  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    lxc_id     = proxmox_virtual_environment_container.storage_server_container.id
    share_dirs = join(",", [for s in var.smb_shares : s.path])
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "root"
      host        = var.ipv4_address
      private_key = tls_private_key.container_key.private_key_pem
      timeout     = "5m"
    }

    inline = concat(
      local.smb_mkdir_commands,
      ["echo 'SMB directories prepared'"]
    )
  }
}

resource "null_resource" "samba_container" {
  count = contains(var.enabled_protocols, "smb") ? 1 : 0

  depends_on = [
    null_resource.prepare_smb_dirs
  ]

  triggers = {
    lxc_id      = proxmox_virtual_environment_container.storage_server_container.id
    user_hash   = sha256(jsonencode(var.smb_user))
    shares_hash = sha256(jsonencode(var.smb_shares))
    config_hash = sha256(local.smb_config)
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
      # 配置 Podman 禁用 AppArmor
      "mkdir -p /etc/containers",
      "echo '[containers]' > /etc/containers/containers.conf",
      "echo 'apparmor_profile = \"\"' >> /etc/containers/containers.conf",

      # 停止并删除旧容器（如果存在）
      "podman stop samba 2>/dev/null || true",
      "podman rm samba 2>/dev/null || true",

      # 拉取镜像
      "podman pull ghcr.io/dockur/samba:4.22.6",

      # 上传自定义配置文件
      <<-EOT
      cat > /tmp/smb.conf <<'SMBEOF'
      ${local.smb_config}
      SMBEOF
      EOT
      ,

      # 构建环境变量参数
      "ENV_ARGS='${join(" ", [for k, v in local.smb_env_vars : "-e ${k}=${v}"])}'",

      # 构建卷挂载参数
      "VOL_ARGS='${join(" ", [for s in var.smb_shares : "-v ${s.path}:/share/${s.name}:${s.read_only != null && s.read_only ? "ro" : "rw"}"])}'",

      # 运行容器
      <<-EOT
      podman run -d \
        --name samba \
        --restart=always \
        --network host \
        $ENV_ARGS \
        -v /tmp/smb.conf:/etc/samba/smb.conf:ro \
        $VOL_ARGS \
        ghcr.io/dockur/samba:4.22.6
      EOT
      ,

      # 等待容器启动
      "sleep 5",

      # 检查容器状态
      "podman ps --filter name=samba --format '{{.Status}}' | grep -q Up || (echo 'Samba container failed to start' && podman logs samba && exit 1)"
    ]
  }
}
