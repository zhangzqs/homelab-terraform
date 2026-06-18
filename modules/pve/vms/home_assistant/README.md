# Home Assistant OS VM 模块

部署 [Home Assistant OS](https://github.com/home-assistant/operating-system) 到 Proxmox VE，使用 HAOS 原生的 `CONFIG` 分区机制注入静态 IP，无需 cloud-init。

## 工作机制

HAOS 是基于 Buildroot 的极简只读镜像，**不内置 cloud-init**。它在启动时由 `haos-config.service` 检查：

1. 卷标为 `CONFIG` 的 USB / CD-ROM 设备
2. 或 boot 分区的 `/mnt/boot/CONFIG/` 目录

如果存在，会把以下内容拷贝到对应位置：
- `CONFIG/network/*.nmconnection` → `/etc/NetworkManager/system-connections/`
- `CONFIG/modules/*` → `/etc/modules-load.d/`
- `CONFIG/modprobe/*` → `/etc/modprobe.d/`
- `CONFIG/udev/*` → `/etc/udev/rules.d/`
- `CONFIG/authorized_keys` → dropbear SSH 调试公钥
- `CONFIG/timesyncd.conf` → systemd-timesyncd

本模块利用这个机制：
1. 通过 SSH 在 **PVE 宿主机** 上下载并解压 HAOS qcow2 镜像到 `/var/lib/vz/import/`。
2. 通过 SSH 在 **PVE 宿主机** 上用 `genisoimage`/`mkisofs`/`xorriso` 构建卷标为 `CONFIG` 的 ISO，直接落到 `/var/lib/vz/template/iso/`。
3. 创建 VM 时通过手工拼接的 file id 把这个 ISO 挂为 CD-ROM（不走 `proxmox_virtual_environment_file` 上传，因为文件已经在宿主机上）。
4. HAOS 首次启动消费 CONFIG，固化静态 IP；后续再启动也是幂等的（haos-config 脚本只在启动时跑一次）。

## 前置依赖

- **本地**：无额外工具链依赖（不需要 xorriso / genisoimage）
- **PVE 宿主机**：`wget`、`unxz`（默认装好），以及以下任一 ISO 构建工具：
  - `genisoimage`（PVE 通常自带，或 `apt install genisoimage`）
  - `mkisofs`
  - `xorriso`

## 使用示例

```hcl
module "home_assistant" {
  source = "github.com/zhangzqs/homelab-terraform//modules/pve/vms/home_assistant?ref=master"

  pve_node_name       = "pve"
  pve_host_ssh_params = var.pve_host_ssh_params
  vm_id               = 208

  haos_version             = "18.0"
  network_interface_bridge = "vmbr0"
  ipv4_address             = "192.168.242.208"
  ipv4_address_cidr        = 24
  ipv4_gateway             = "192.168.242.1"
  ipv4_dns                 = "192.168.242.204;223.5.5.5"

  cpu_cores  = 2
  memory     = 4096
  disk_size  = 32

  # USB 直通（可选，按需填）
  usb_devices = [
    # ConBee II / Sonoff Zigbee 3.0 / SkyConnect 等
    # { host = "10c4:ea60" },
  ]

  providers = {
    proxmox = proxmox
  }
}
```

## 注意事项

- **HAOS 版本升级**：通过 HA UI 触发 OTA 升级，**不要**在 Terraform 里改 `haos_version` 后 apply —— 这会触发镜像重新 `import`，把根盘替换掉，**所有数据丢失**。模块已加 `lifecycle.ignore_changes = [disk]` 防误触。仅在首次创建或彻底重装时才改这个值。
- **网卡接口名**：HAOS（基于 Buildroot + systemd）使用 predictable interface names。本模块的 `nmconnection` 不绑定 `interface-name`，依赖 `connection.id` + `type=ethernet` 自动匹配第一块以太网卡。如果有多网卡需求，自行扩展模板。
- **MAC 地址**：建议传入固定 MAC，便于在路由器或 DHCP 侧做静态绑定（即便我们已经通过 NM 注入静态 IP，固定 MAC 也方便防火墙规则、设备审计）。
- **CD-ROM 一次性**：CONFIG ISO 即便长期挂着也无副作用（haos-config 仅在启动时跑一次拷贝）。如果想清理，apply 完成后手工在 PVE Web UI 把 ide2 设为 "do not use" 即可。

## 输出

| 名称 | 描述 |
|---|---|
| `vm_id` | VM ID |
| `vm_ip` | 静态 IP |
| `ha_url` | `http://<ip>:8123` |
| `config_iso_file_id` | CONFIG ISO 的 PVE file id |
