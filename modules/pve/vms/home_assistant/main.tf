// =============================================================================
// 准备工作均在 PVE 宿主机上完成（通过 SSH）：
//   1. 下载并解压 HAOS qcow2 镜像 -> /var/lib/vz/import/
//   2. 用 genisoimage 构造卷标为 CONFIG 的 ISO -> /var/lib/vz/template/iso/
// 这样模块对本地工具链零依赖，也省掉 proxmox_virtual_environment_file 上传环节。
// =============================================================================

// SSH 连接参数（多个资源复用，写在一起避免漂移）
locals {
  pve_ssh_host     = var.pve_host_ssh_params.ssh_host
  pve_ssh_port     = var.pve_host_ssh_params.ssh_port
  pve_ssh_user     = var.pve_host_ssh_params.ssh_user
  pve_ssh_password = var.pve_host_ssh_params.ssh_password
}

// =============================================================================
// 1. 在 PVE 宿主机上下载并解压 HAOS qcow2 镜像
//    bpg/proxmox 0.93.0 的 download_file 不支持 xz 解压算法，
//    HAOS 官方发布只提供 .qcow2.xz，所以走 SSH 在宿主机侧下载。
// =============================================================================
resource "terraform_data" "haos_image_prepare" {
  triggers_replace = {
    haos_version = var.haos_version
    datastore_id = var.haos_image_datastore_id
  }

  connection {
    type     = "ssh"
    host     = local.pve_ssh_host
    port     = local.pve_ssh_port
    user     = local.pve_ssh_user
    password = local.pve_ssh_password
  }

  provisioner "remote-exec" {
    inline = [
      "set -euo pipefail",
      "TARGET_DIR=/var/lib/vz/import",
      "mkdir -p \"$TARGET_DIR\"",
      "TARGET_FILE=\"$TARGET_DIR/haos_ova-${self.triggers_replace.haos_version}.qcow2\"",
      "if [ ! -f \"$TARGET_FILE\" ]; then",
      "  TMP_XZ=\"$TARGET_DIR/haos_ova-${self.triggers_replace.haos_version}.qcow2.xz\"",
      "  rm -f \"$TMP_XZ\"",
      "  wget --tries=3 --timeout=60 -O \"$TMP_XZ\" 'https://github.com/home-assistant/operating-system/releases/download/${self.triggers_replace.haos_version}/haos_ova-${self.triggers_replace.haos_version}.qcow2.xz'",
      "  unxz \"$TMP_XZ\"",
      "fi",
      "ls -lh \"$TARGET_FILE\"",
    ]
  }
}

locals {
  // HAOS 系统盘镜像在 PVE 上的 file id（通过 import datastore 引用）
  haos_image_file_id = "${var.haos_image_datastore_id}:import/haos_ova-${var.haos_version}.qcow2"
}

// =============================================================================
// 2. 在 PVE 宿主机上构造 CONFIG ISO
//    HAOS 第一次启动时 haos-config.service 会读取 LABEL=CONFIG 的卷，
//    把 network/*.nmconnection 拷贝到 /etc/NetworkManager/system-connections/。
// =============================================================================
locals {
  nmconnection_content = templatefile("${path.module}/templates/static-ethernet.nmconnection.tftpl", {
    ipv4_address = var.ipv4_address
    ipv4_cidr    = var.ipv4_address_cidr
    ipv4_gateway = var.ipv4_gateway
    ipv4_dns     = var.ipv4_dns
  })

  // 同一个 PVE 上多 HA VM 时按 vm_id 隔离
  config_iso_file_name = "haos-config-${var.vm_id}.iso"
  config_iso_remote    = "/var/lib/vz/template/iso/${local.config_iso_file_name}"
  config_iso_file_id   = "${var.config_iso_datastore_id}:iso/${local.config_iso_file_name}"
}

resource "terraform_data" "config_iso_build" {
  triggers_replace = {
    content      = sha256(local.nmconnection_content)
    iso_path     = local.config_iso_remote
    datastore_id = var.config_iso_datastore_id
    ssh_host     = local.pve_ssh_host
    ssh_port     = local.pve_ssh_port
    ssh_user     = local.pve_ssh_user
    ssh_password = local.pve_ssh_password
  }

  connection {
    type     = "ssh"
    host     = self.triggers_replace.ssh_host
    port     = self.triggers_replace.ssh_port
    user     = self.triggers_replace.ssh_user
    password = self.triggers_replace.ssh_password
  }

  // 把 nmconnection 内容写到宿主机临时目录，再 mkisofs 打包
  // 注意：HAOS 的 haos-config 脚本对 LABEL=CONFIG 大小写敏感
  provisioner "remote-exec" {
    inline = [
      "set -euo pipefail",
      "WORKDIR=$(mktemp -d)",
      "trap 'rm -rf \"$WORKDIR\"' EXIT",
      "mkdir -p \"$WORKDIR/network\"",
      "cat > \"$WORKDIR/network/static-ethernet.nmconnection\" <<'NMCFG'\n${local.nmconnection_content}\nNMCFG",
      "chmod 600 \"$WORKDIR/network/static-ethernet.nmconnection\"",
      "mkdir -p \"$(dirname '${self.triggers_replace.iso_path}')\"",
      "if command -v genisoimage >/dev/null 2>&1; then ISO_CMD=genisoimage; elif command -v mkisofs >/dev/null 2>&1; then ISO_CMD=mkisofs; elif command -v xorriso >/dev/null 2>&1; then ISO_CMD='xorriso -as mkisofs'; else echo 'No ISO tool found (install genisoimage/mkisofs/xorriso on PVE host)' >&2; exit 1; fi",
      "$ISO_CMD -V CONFIG -J -r -o '${self.triggers_replace.iso_path}' \"$WORKDIR\"",
      "ls -lh '${self.triggers_replace.iso_path}'",
    ]
  }

  // 销毁时清理 ISO（每个 VM 独享，按 vm_id 命名）
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "rm -f '${self.triggers_replace.iso_path}'",
    ]
  }
}

// =============================================================================
// 3. 创建 Home Assistant OS 虚拟机
// =============================================================================
resource "proxmox_virtual_environment_vm" "home_assistant" {
  depends_on = [
    terraform_data.haos_image_prepare,
    terraform_data.config_iso_build,
  ]

  node_name   = var.pve_node_name
  vm_id       = var.vm_id
  name        = var.name
  description = "Terraform 自动创建的 Home Assistant OS"
  tags        = ["home-assistant", "terraform"]

  stop_on_destroy = true
  started         = true
  on_boot         = true

  // HAOS 必须 UEFI + q35
  bios    = "ovmf"
  machine = "q35"

  efi_disk {
    datastore_id = var.disk_datastore_id
    type         = "4m"
  }

  // HAOS 16+ 内置 qemu-guest-agent
  agent {
    enabled = true
    timeout = "10m"
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  network_device {
    enabled     = true
    bridge      = var.network_interface_bridge
    model       = "virtio"
    mac_address = var.mac_address
  }

  // 系统盘：从 HAOS qcow2 import
  disk {
    datastore_id = var.disk_datastore_id
    import_from  = local.haos_image_file_id
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  scsi_hardware = "virtio-scsi-single"

  // CD-ROM：挂载 CONFIG ISO 用于首次启动注入网络配置
  // q35 机型仅支持 ide0 / ide2
  cdrom {
    file_id   = local.config_iso_file_id
    interface = "ide2"
  }

  // USB 直通（Zigbee / Z-Wave / 蓝牙 dongle）
  dynamic "usb" {
    for_each = var.usb_devices
    content {
      host = usb.value.host
      usb3 = usb.value.usb3
    }
  }

  operating_system {
    type = "l26"
  }

  // HAOS 通过自身 OTA 升级，不让 Terraform 干涉系统盘
  lifecycle {
    ignore_changes = [
      disk,
    ]
  }
}
