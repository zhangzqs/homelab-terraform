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

resource "proxmox_virtual_environment_container" "storage_server_container" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.container_replacer
    ]
    prevent_destroy = true # 这是个有状态容器，禁止在terraform中销毁
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
    "if ! mountpoint -q ${export.path} 2>/dev/null; then mkdir -p ${export.path} && chmod 777 ${export.path}; fi"
    if !contains(local.mounted_paths, export.path)
  ]

  # 生成 SMB 配置
  smb_config = templatefile("${path.module}/templates/smb.conf.tftpl", {
    workgroup     = var.smb_workgroup
    server_string = var.smb_server_string
    shares        = var.smb_shares
  })

  # 生成 SMB 目录创建命令（跳过已挂载的目录）
  smb_mkdir_commands = [
    for share in var.smb_shares :
    "if ! mountpoint -q ${share.path} 2>/dev/null; then mkdir -p ${share.path} && chmod 777 ${share.path}; fi"
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

# SMB 配置
resource "null_resource" "configure_smb" {
  count = contains(var.enabled_protocols, "smb") ? 1 : 0

  depends_on = [
    null_resource.setup_container
  ]

  triggers = {
    version    = 2
    lxc_id     = proxmox_virtual_environment_container.storage_server_container.id
    smb_config = sha256(local.smb_config)
  }

  provisioner "file" {
    content     = local.smb_config
    destination = "/tmp/smb.conf"

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

    inline = concat(
      local.smb_mkdir_commands,
      [
        "cp /tmp/smb.conf /etc/samba/smb.conf",
        "rm -f /tmp/smb.conf",
        "systemctl restart smbd nmbd",
        "sleep 2",
        "systemctl status smbd --no-pager || true",
        "systemctl status nmbd --no-pager || true",
        "testparm -s || true",
      ]
    )
  }
}
