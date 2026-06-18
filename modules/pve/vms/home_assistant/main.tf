// =============================================================================
// Home Assistant OS VM 模块
//
// 难点：HAOS 不支持 cloud-init（基于 Buildroot 的极简只读镜像，无 Python）。
// 它原生有一个 `hassos-config.service`（也叫 haos-config）会在启动时检查
// LABEL=CONFIG 的 USB/CD 卷，把 network/*.nmconnection 拷贝到
// /etc/NetworkManager/system-connections/。但实测 HAOS 17.x 在拷贝完成后，
// HA Supervisor 容器仍会通过 NM DBus 把 enp* 接口重置回 DHCP（出厂模板）。
// 所以模块走"先让 VM 起来拿 DHCP IP -> 通过 qemu-guest-agent 直接改 NM
// 连接为 manual"的路子，比 CONFIG ISO 注入可靠。
//
// 准备工作均在 PVE 宿主机上完成（通过 SSH）：
//   1. 下载并解压 HAOS qcow2 镜像 -> /var/lib/vz/import/
//   2. 创建 VM
//   3. 通过 qm guest exec 让 HAOS 内部把出厂 `Supervisor <iface>` 连接
//      改成 manual + 静态 IP，并重新激活
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
      var.download_proxy == null ? "true" : "export http_proxy='${var.download_proxy.http_proxy}'",
      var.download_proxy == null ? "true" : "export https_proxy='${var.download_proxy.https_proxy}'",
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
// 2. 创建 Home Assistant OS 虚拟机
// =============================================================================
resource "proxmox_virtual_environment_vm" "home_assistant" {
  depends_on = [terraform_data.haos_image_prepare]

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

// =============================================================================
// 3. 通过 qm guest exec 给 HAOS 注入静态 IP
//    HAOS 出厂自带一个 `Supervisor <iface>` NetworkManager 连接（DHCP），
//    我们用 `nmcli con modify` 把它改成 manual + 我们的 IP，再重新激活。
//    比往 LABEL=CONFIG 卷拷文件更可靠：
//      - hassos-config 拷贝完成后，HA Supervisor 仍可能经 DBus 重置回 DHCP
//      - 直接改活跃连接，立即生效，不需要重启
// =============================================================================
resource "terraform_data" "configure_static_ip" {
  depends_on = [proxmox_virtual_environment_vm.home_assistant]

  triggers_replace = {
    vm_id          = var.vm_id
    interface_name = var.interface_name
    ipv4_address   = var.ipv4_address
    ipv4_cidr      = var.ipv4_address_cidr
    ipv4_gateway   = var.ipv4_gateway
    // nmcli ipv4.dns 用逗号分隔，模板里是分号给 keyfile 用
    ipv4_dns_csv = replace(var.ipv4_dns, ";", ",")
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

  // 等 guest agent 起来 -> 改 NM 连接 -> 重新激活
  // HAOS 启动到 supervisor 起来大约 1-2 分钟，guest agent 更早可用
  provisioner "remote-exec" {
    inline = [
      "set -euo pipefail",
      "VMID='${self.triggers_replace.vm_id}'",
      "IFACE='${self.triggers_replace.interface_name}'",
      "CONN_NAME=\"Supervisor $IFACE\"",
      // 等 guest agent 至多 5 分钟
      "echo '[+] waiting qemu-guest-agent on VM '$VMID",
      "for i in $(seq 1 60); do",
      "  if qm guest cmd $VMID ping >/dev/null 2>&1; then echo '    agent up after '$((i*5))'s'; break; fi",
      "  sleep 5",
      "done",
      "qm guest cmd $VMID ping >/dev/null 2>&1 || { echo 'guest agent not responding' >&2; exit 1; }",
      // 等 NetworkManager 起来并加载出厂 Supervisor 连接（HA Supervisor 反推下来）
      "echo '[+] waiting NetworkManager Supervisor connection'",
      "for i in $(seq 1 60); do",
      "  if qm guest exec $VMID -- /bin/sh -c \"nmcli -t -f NAME con show | grep -qx 'Supervisor $IFACE'\" 2>/dev/null | grep -q '\"exitcode\" : 0'; then echo '    Supervisor conn ready after '$((i*5))'s'; break; fi",
      "  sleep 5",
      "done",
      // 改 IP + 重新激活；nmcli 设置 manual 时必须同时给 addresses
      "echo '[+] applying static IP via nmcli'",
      "qm guest exec $VMID -- /bin/sh -c \"nmcli con modify '$CONN_NAME' ipv4.method manual ipv4.addresses '${self.triggers_replace.ipv4_address}/${self.triggers_replace.ipv4_cidr}' ipv4.gateway '${self.triggers_replace.ipv4_gateway}' ipv4.dns '${self.triggers_replace.ipv4_dns_csv}' && nmcli con reload && nmcli con up '$CONN_NAME'\"",
      "echo '[+] done'",
    ]
  }
}
