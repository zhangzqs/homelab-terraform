# Homelab Terraform Modules

可复用的 Terraform 模块集合，用于部署基于 Proxmox VE 的家庭实验室基础设施。

## 模块列表

### `modules/pve/` - Proxmox VE 基础设施模块

| 模块 | 说明 |
|------|------|
| `modules/pve/host_configure/` | PVE 主机基础配置（DNS、网络等） |
| `modules/pve/lxc_templates/` | LXC 容器模板下载管理 |
| `modules/pve/vm_cloud_images/` | VM Cloud Image 下载管理 |
| `modules/pve/lxcs/code_server/` | Code Server (Web VS Code) LXC 容器 |
| `modules/pve/lxcs/coredns/` | CoreDNS DNS 服务器 LXC 容器 |
| `modules/pve/lxcs/mihomo_proxy/` | Mihomo 代理 LXC 容器 |
| `modules/pve/lxcs/nginx/` | Nginx 反向代理 LXC 容器 |
| `modules/pve/lxcs/storage_server/` | 存储服务器 LXC 容器（NFS/SMB） |
| `modules/pve/lxcs/tailscale/` | Tailscale VPN LXC 容器 |
| `modules/pve/vms/k3s_master/` | K3s 主节点虚拟机 |

### `modules/k8s/` - Kubernetes 模块

| 模块 | 说明 |
|------|------|
| `modules/k8s/all_in_one/` | K8s 一键部署聚合模块 |
| `modules/k8s/base/gateway/` | Gateway API 配置 |
| `modules/k8s/base/nfs_csi/` | NFS CSI 驱动 |
| `modules/k8s/base/nfs_storage_class/` | NFS StorageClass |
| `modules/k8s/base/victoriametrics-operator/` | VictoriaMetrics 监控 |
| `modules/k8s/apps/common_simple_app/` | 通用简单应用模块 |
| `modules/k8s/apps/drawio/` | Draw.io 在线绘图 |
| `modules/k8s/apps/it_tools/` | IT Tools 工具箱 |
| `modules/k8s/apps/plantuml/` | PlantUML 服务 |
| `modules/k8s/apps/speedtest/` | Speedtest 测速服务 |
| `modules/k8s/apps/vaultwarden/` | Vaultwarden 密码管理 |

### `modules/utils/` - 工具模块

| 模块 | 说明 |
|------|------|
| `modules/utils/acme_certs/` | ACME/Let's Encrypt 证书自动管理 |
| `modules/utils/auto_disk_mount/` | 自动磁盘挂载 |
| `modules/utils/lxc_mount_point/` | LXC 挂载点管理 |
| `modules/utils/mihomo_config_generator/` | Mihomo 配置文件生成器 |
| `modules/utils/nginx_config_generator/` | Nginx 配置文件生成器 |

## 使用方式

### 引用模块

```hcl
module "k3s_master" {
  source = "github.com/zhangzqs/homelab-terraform//modules/pve/vms/k3s_master?ref=master"

  pve_node_name         = "pve"
  pve_endpoint          = "https://your-pve-host:8006"
  pve_username          = "root@pam"
  pve_password          = var.pve_password
  vm_id                 = 202
  ubuntu_cloud_image_id = "local:iso/ubuntu-24.04-cloudimg-amd64.img"
  network_interface_bridge = "vmbr0"
  ipv4_address          = "192.168.242.202"
  ipv4_address_cidr     = 24
  ipv4_gateway          = "192.168.242.1"
}
```

### 私有配置仓库

Stack 配置（tfvars、state 文件等敏感数据）存放在私有仓库 [homelab-terraform-stacks](https://github.com/zhangzqs/homelab-terraform-stacks)，通过 `git@github.com:` SSH URL 引用本仓库的模块。

## 项目结构

```text
.
├── modules/
│   ├── k8s/                  # Kubernetes 相关模块
│   │   ├── all_in_one/       # K8s 一键部署聚合模块
│   │   ├── base/             # K8s 基础组件
│   │   └── apps/             # K8s 应用部署
│   ├── pve/                  # Proxmox VE 基础设施模块
│   │   ├── host_configure/   # PVE 主机配置
│   │   ├── lxc_templates/    # LXC 模板管理
│   │   ├── lxcs/             # LXC 容器模块
│   │   ├── vm_cloud_images/  # VM 镜像管理
│   │   └── vms/              # 虚拟机模块
│   └── utils/                # 工具模块
│       ├── acme_certs/       # ACME 证书管理
│       ├── auto_disk_mount/  # 自动磁盘挂载
│       ├── lxc_mount_point/  # LXC 挂载点管理
│       ├── mihomo_config_generator/  # Mihomo 配置生成
│       └── nginx_config_generator/   # Nginx 配置生成
└── .github/workflows/        # CI 配置
```

## 代码统计

<!-- tokei-start -->
```
===============================================================================
 Language            Files        Lines         Code     Comments       Blanks
===============================================================================
 HCL                   107         7401         5790          642          969
 Pan                    21         1154          860          120          174
 Shell                  16         1025          677          157          191
-------------------------------------------------------------------------------
 Markdown                9         1028            0          731          297
 |- BASH                 6          186           96           59           31
 |- HCL                  8          477          373           46           58
 |- YAML                 1            6            6            0            0
 (Total)                           1697          475          836          386
===============================================================================
 Total                 153        10608         7327         1650         1631
===============================================================================
```
<!-- tokei-end -->

## 许可证

本项目采用 [MIT License](LICENSE) 开源协议。
