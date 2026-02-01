# K3s Master 虚拟机模块

这个 Terraform 模块用于在 Proxmox VE 上创建一个运行 K3s 主节点的虚拟机。

## 功能特性

- 基于 Ubuntu Cloud Image 创建虚拟机
- 自动配置网络（静态 IP）
- 自动安装和配置 K3s master 节点
- 支持 Containerd 代理配置
- 使用 SSH 密钥和密码进行身份验证
- 自动更新 apt 源为国内镜像

## 前置要求

- Proxmox VE 环境
- Ubuntu Cloud Image 模板
- Terraform >= 1.0
- bpg/proxmox provider

## 使用示例

### 1. 下载 Ubuntu Cloud Image

首先需要下载 Ubuntu Cloud Image 到 Proxmox：

```hcl
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve"
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
}
```

### 2. 创建 K3s Master 虚拟机

```hcl
module "k3s_master" {
  source = "./tf-pve/vms/k3s_master"

  # 基本配置
  hostname              = "k3s-master-01"
  pve_node_name         = "pve"
  vm_id                 = 200
  ubuntu_cloud_image_id = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id

  # 网络配置
  network_interface_bridge = "vmbr0"
  ipv4_address            = "192.168.1.100"
  ipv4_address_cidr       = 24
  ipv4_gateway            = "192.168.1.1"

  # 资源配置
  cpu_cores    = 4
  memory       = 4096
  disk_size    = 32
  datastore_id = "local-lvm"

  # 可选：代理配置
  containerd_proxy = {
    http_proxy  = "http://proxy.example.com:7890"
    https_proxy = "http://proxy.example.com:7890"
    no_proxy    = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
  }
}
```

## 输入变量

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `hostname` | string | `"k3s-master"` | 虚拟机主机名 |
| `ubuntu_cloud_image_id` | string | - | Ubuntu Cloud Image 资源 ID（必需） |
| `vm_id` | number | - | 虚拟机 ID（必需） |
| `pve_node_name` | string | - | Proxmox 节点名称（必需） |
| `network_interface_bridge` | string | `"vmbr0"` | 网络桥接设备 |
| `ipv4_address` | string | - | IPv4 地址（必需） |
| `ipv4_address_cidr` | number | `24` | IPv4 CIDR 前缀长度 |
| `ipv4_gateway` | string | - | IPv4 网关（必需） |
| `cpu_cores` | number | `4` | CPU 核心数 |
| `memory` | number | `4096` | 内存大小（MB） |
| `disk_size` | number | `32` | 磁盘大小（GB） |
| `datastore_id` | string | `"local-lvm"` | 数据存储 ID |
| `containerd_proxy` | object | `null` | Containerd 代理配置 |

## 输出

| 输出名 | 说明 | 敏感 |
|--------|------|------|
| `vm_password` | root 用户密码 | 是 |
| `vm_private_key` | SSH 私钥 | 是 |
| `vm_public_key` | SSH 公钥 | 否 |
| `vm_ip` | 虚拟机 IP 地址 | 否 |
| `kubeconfig` | K3s kubeconfig 文件内容 | 是 |

## 与 LXC 版本的区别

相比 `lxc_containers/k3s_master` 模块，VM 版本有以下主要区别：

1. **资源隔离**：VM 提供更好的隔离性和安全性
2. **配置简化**：不需要 LXC 特定的宿主机配置（如 AppArmor、cgroup 等）
3. **资源配置**：VM 通常需要更多的内存和 CPU 资源
4. **启动时间**：VM 启动时间较 LXC 容器略长
5. **兼容性**：VM 对 K3s 的兼容性更好，不需要特殊的内核配置

## 部署流程

1. 上传 cloud-init 配置到 Proxmox
2. 创建虚拟机（基于 Ubuntu Cloud Image）
3. Cloud-init 自动配置虚拟机环境（更新 apt 源、安装软件包、配置 SSH）
4. 通过 SSH 安装 K3s master 节点
5. 配置 Containerd 代理（可选）

## 注意事项

- 确保 Proxmox 节点上的 `local` 存储支持 `snippets` 类型（用于存储 cloud-init 配置）
- 确保指定的 IP 地址未被占用
- K3s 安装使用中国镜像，加速下载
- 虚拟机会自动配置为开机启动
- SSH 支持密钥和密码两种认证方式
- qemu-guest-agent 会自动安装并启动

## 访问虚拟机

获取 SSH 私钥：

```bash
terraform output -raw vm_private_key > k3s_master_key.pem
chmod 600 k3s_master_key.pem
```

使用 SSH 连接：

```bash
ssh -i k3s_master_key.pem root@<vm_ip>
```

或使用密码：

```bash
terraform output -raw vm_password
ssh root@<vm_ip>
```

## 获取 K3s kubeconfig

### 方式 1：通过 Terraform Output（推荐）

```bash
# 查看 kubeconfig 内容
terraform output -raw kubeconfig

# 保存到文件
terraform output -raw kubeconfig > kubeconfig.yaml

# 使用 kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig.yaml
kubectl get nodes
```

**注意**：kubeconfig 中的 server 地址已自动替换为虚拟机的实际 IP 地址，可直接使用。

### 方式 2：通过 SSH 直接获取

```bash
ssh -i k3s_master_key.pem root@<vm_ip> "cat /etc/rancher/k3s/k3s.yaml"
```

此方式获取的 kubeconfig 需要手动修改 server 地址：

```bash
ssh -i k3s_master_key.pem root@<vm_ip> "cat /etc/rancher/k3s/k3s.yaml" | \
  sed "s/127.0.0.1/<vm_ip>/g" > kubeconfig.yaml
```

## 许可证

MIT
