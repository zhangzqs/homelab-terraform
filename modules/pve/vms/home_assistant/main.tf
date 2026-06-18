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
//   4. （可选）通过 qm guest exec 给 HA configuration.yaml 注入
//      http.use_x_forwarded_for + trusted_proxies，让 nginx 反代能正常工作
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
locals {
  download_haos_image_script = templatefile(
    "${path.module}/scripts/download_haos_image.sh.tpl",
    {
      haos_version           = var.haos_version
      download_proxy_enabled = var.download_proxy != null
      http_proxy             = var.download_proxy != null ? var.download_proxy.http_proxy : ""
      https_proxy            = var.download_proxy != null ? var.download_proxy.https_proxy : ""
    }
  )
}

resource "terraform_data" "haos_image_prepare" {
  triggers_replace = {
    haos_version = var.haos_version
    datastore_id = var.haos_image_datastore_id
    script_hash  = sha256(local.download_haos_image_script)
  }

  connection {
    type     = "ssh"
    host     = local.pve_ssh_host
    port     = local.pve_ssh_port
    user     = local.pve_ssh_user
    password = local.pve_ssh_password
  }

  provisioner "remote-exec" {
    inline = [local.download_haos_image_script]
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
// =============================================================================
locals {
  configure_static_ip_script = templatefile(
    "${path.module}/scripts/configure_static_ip.sh.tpl",
    {
      vm_id          = var.vm_id
      interface_name = var.interface_name
      ipv4_address   = var.ipv4_address
      ipv4_cidr      = var.ipv4_address_cidr
      ipv4_gateway   = var.ipv4_gateway
      // nmcli ipv4.dns 用逗号分隔，模板里是分号给 keyfile 用
      ipv4_dns_csv = replace(var.ipv4_dns, ";", ",")
    }
  )
}

resource "terraform_data" "configure_static_ip" {
  depends_on = [proxmox_virtual_environment_vm.home_assistant]

  triggers_replace = {
    vm_id       = var.vm_id
    script_hash = sha256(local.configure_static_ip_script)
  }

  connection {
    type     = "ssh"
    host     = local.pve_ssh_host
    port     = local.pve_ssh_port
    user     = local.pve_ssh_user
    password = local.pve_ssh_password
  }

  provisioner "remote-exec" {
    inline = [local.configure_static_ip_script]
  }
}

// =============================================================================
// 4. 通过 qm guest exec 给 HA 注入 trusted_proxies
//    用于反代场景：nginx -> HA 时 HA 必须信任反代源 IP，否则被拒。
//    幂等设计：onboarding 未完成时（configuration.yaml 不存在）静默跳过，
//             onboarding 完成后再 apply 才生效；后续重跑只在内容变化时改。
// =============================================================================
locals {
  trusted_proxies_marker_begin = "BEGIN terraform-managed trusted_proxies"
  trusted_proxies_marker_end   = "END terraform-managed trusted_proxies"

  trusted_proxies_yaml_block = join("\n", concat(
    ["# ${local.trusted_proxies_marker_begin}", "http:", "  use_x_forwarded_for: true", "  trusted_proxies:"],
    [for p in var.trusted_proxies : "    - ${p}"],
    ["# ${local.trusted_proxies_marker_end}"]
  ))

  inject_trusted_proxies_script = templatefile(
    "${path.module}/scripts/inject_trusted_proxies.sh.tpl",
    {
      vm_id        = var.vm_id
      config_path  = var.ha_config_path
      marker_begin = local.trusted_proxies_marker_begin
      marker_end   = local.trusted_proxies_marker_end
      yaml_block   = local.trusted_proxies_yaml_block
    }
  )
}

resource "terraform_data" "inject_trusted_proxies" {
  count = length(var.trusted_proxies) > 0 ? 1 : 0

  depends_on = [terraform_data.configure_static_ip]

  triggers_replace = {
    vm_id       = var.vm_id
    script_hash = sha256(local.inject_trusted_proxies_script)
  }

  connection {
    type     = "ssh"
    host     = local.pve_ssh_host
    port     = local.pve_ssh_port
    user     = local.pve_ssh_user
    password = local.pve_ssh_password
  }

  provisioner "remote-exec" {
    inline = [local.inject_trusted_proxies_script]
  }
}
