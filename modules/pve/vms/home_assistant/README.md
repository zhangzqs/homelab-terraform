# Home Assistant OS VM 模块

部署 [Home Assistant OS](https://github.com/home-assistant/operating-system) 到 Proxmox VE。

## 工作机制

HAOS 是基于 Buildroot 的极简只读镜像，**不支持 cloud-init**（无 Python）。

理论上 HAOS 自带的 `hassos-config.service` 会在启动时检查卷标 `CONFIG` 的 USB/CD 设备并拷贝 `network/*.nmconnection` 到 NetworkManager 目录，但实测 HAOS 17.x 在拷贝完成后，**HA Supervisor 容器仍会通过 NM DBus 把 `enp*` 接口重置回 DHCP**（出厂模板）—— CONFIG ISO 路线注入的连接被覆盖。

所以本模块改用更直接、更可靠的路径：

1. 通过 SSH 在 **PVE 宿主机** 上下载并解压 HAOS qcow2 镜像到 `/var/lib/vz/import/`（bpg/proxmox 0.93 的 `download_file` 不支持 `xz` 解压）。
2. 创建 VM（UEFI + q35，HAOS 必需）。
3. 通过 `qm guest exec` 等 qemu-guest-agent 上线后，直接用 `nmcli con modify 'Supervisor <iface>' ipv4.method manual ...` 改 HAOS 出厂自带的 NetworkManager 连接为静态 IP，立即生效。

## 前置依赖

- **本地**：无（不依赖 xorriso / genisoimage）
- **PVE 宿主机**：`wget`、`unxz`（默认装好）；`qm guest exec` 依赖 VM 内的 qemu-guest-agent，HAOS 16+ 内置

## 使用示例

```hcl
module "home_assistant" {
  source = "github.com/zhangzqs/homelab-terraform//modules/pve/vms/home_assistant?ref=master"

  pve_node_name       = "pve"
  pve_host_ssh_params = var.pve_host_ssh_params
  vm_id               = 208

  haos_version             = "17.3"
  network_interface_bridge = "vmbr0"
  ipv4_address             = "192.168.242.208"
  ipv4_address_cidr        = 24
  ipv4_gateway             = "192.168.242.1"
  ipv4_dns                 = "192.168.242.204;223.5.5.5"

  cpu_cores  = 2
  memory     = 4096
  disk_size  = 32

  // GitHub 直连慢的内网用 mihomo 加速
  download_proxy = {
    http_proxy  = "http://192.168.242.200:7890"
    https_proxy = "http://192.168.242.200:7890"
  }

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
- **interface_name**：默认 `enp6s18`，是 PVE q35 + virtio + ovmf 拓扑下 HAOS 出厂使用的接口名。如果未来 PVE 拓扑变化（比如改用 PCIe passthrough 或不同机型），可能需要调整。
- **MAC 地址**：建议传入固定 `mac_address`，便于在路由器或 DHCP 侧做静态绑定（即便我们已经通过 nmcli 注入静态 IP，固定 MAC 也方便防火墙规则、设备审计）。
- **首次 apply 耗时**：HAOS 镜像 ~530MB，加上 VM 创建 + Supervisor 启动 + 静态 IP 注入，整体约 4-5 分钟。

## 输出

| 名称 | 描述 |
|---|---|
| `vm_id` | VM ID |
| `vm_ip` | 静态 IP |
| `ha_url` | `http://<ip>:8123` |

