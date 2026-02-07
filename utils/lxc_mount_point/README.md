# LXC 挂载点模块

这个 Terraform 模块用于通过 SSH 连接到 Proxmox VE 宿主机，并将宿主机目录挂载到 LXC 容器中。模块保证了操作的幂等性。

## 功能特性

- ✅ **幂等性保证**：检测现有挂载配置，避免重复操作
- ✅ **智能更新**：当配置变化时自动更新挂载点
- ✅ **灵活配置**：支持自定义挂载选项、容器重启策略
- ✅ **安全清理**：销毁时自动卸载挂载点
- ✅ **详细日志**：提供清晰的操作日志和错误信息

## 使用示例

### 基本用法

```hcl
module "lxc_mount" {
  source = "../utils/lxc_mount_point"

  # SSH 连接参数
  ssh_host     = "192.168.1.100"
  ssh_user     = "root"
  ssh_password = "your-password"

  # LXC 容器配置
  container_id   = 243
  mount_point_id = "mp0"

  # 挂载路径
  host_path      = "/mnt/hdd-disk"
  container_path = "/mnt/mydisk"

  # 挂载后重启容器
  restart_container = true
}
```

### 多个挂载点

```hcl
module "lxc_mount_disk1" {
  source = "../utils/lxc_mount_point"

  ssh_host       = var.pve_host_ssh_params.ssh_host
  ssh_user       = var.pve_host_ssh_params.ssh_user
  ssh_password   = var.pve_host_ssh_params.ssh_password

  container_id   = 243
  mount_point_id = "mp0"
  host_path      = "/mnt/hdd-disk"
  container_path = "/mnt/hdd"
}

module "lxc_mount_disk2" {
  source = "../utils/lxc_mount_point"

  ssh_host       = var.pve_host_ssh_params.ssh_host
  ssh_user       = var.pve_host_ssh_params.ssh_user
  ssh_password   = var.pve_host_ssh_params.ssh_password

  container_id   = 243
  mount_point_id = "mp1"
  host_path      = "/mnt/ssd-disk"
  container_path = "/mnt/ssd"
}
```

### 使用 SSH 私钥认证

```hcl
module "lxc_mount" {
  source = "../utils/lxc_mount_point"

  ssh_host        = "192.168.1.100"
  ssh_user        = "root"
  ssh_private_key = file("~/.ssh/id_rsa")

  container_id   = 243
  mount_point_id = "mp0"
  host_path      = "/mnt/hdd-disk"
  container_path = "/mnt/mydisk"
}
```

### 带挂载选项

```hcl
module "lxc_mount" {
  source = "../utils/lxc_mount_point"

  ssh_host     = "192.168.1.100"
  ssh_user     = "root"
  ssh_password = "your-password"

  container_id   = 243
  mount_point_id = "mp0"
  host_path      = "/mnt/hdd-disk"
  container_path = "/mnt/mydisk"

  # 添加挂载选项
  mount_options = ["backup=1", "replicate=1"]

  # 挂载前先停止容器
  stop_before_mount = true
  restart_container = true
}
```

## 输入变量

| 变量名 | 类型 | 默认值 | 必填 | 说明 |
|--------|------|--------|------|------|
| `ssh_host` | string | - | ✅ | PVE 宿主机 SSH 地址 |
| `ssh_port` | number | 22 | ❌ | SSH 端口 |
| `ssh_user` | string | "root" | ❌ | SSH 用户名 |
| `ssh_password` | string | null | ❌ | SSH 密码 |
| `ssh_private_key` | string | null | ❌ | SSH 私钥路径或内容 |
| `container_id` | number | - | ✅ | LXC 容器 ID |
| `mount_point_id` | string | "mp0" | ❌ | 挂载点 ID (mp0-mp9) |
| `host_path` | string | - | ✅ | 宿主机目录路径（绝对路径） |
| `container_path` | string | - | ✅ | 容器内挂载点路径（绝对路径） |
| `mount_options` | list(string) | [] | ❌ | 挂载选项（如 backup=1） |
| `restart_container` | bool | true | ❌ | 挂载后是否重启容器 |
| `stop_before_mount` | bool | false | ❌ | 挂载前是否停止容器 |

## 输出变量

| 变量名 | 说明 |
|--------|------|
| `container_id` | LXC 容器 ID |
| `mount_point_id` | 挂载点 ID |
| `host_path` | 宿主机路径 |
| `container_path` | 容器内路径 |
| `mount_config` | 完整的挂载配置字符串 |

## 工作原理

### 挂载流程

1. **检查前置条件**
   - 验证宿主机路径是否存在
   - 验证容器是否存在

2. **幂等性检查**
   - 获取容器当前挂载配置
   - 比较当前配置与期望配置
   - 如果相同则跳过，不同则更新

3. **执行挂载**
   - 如果配置需要，先停止容器
   - 执行 `pct set` 命令配置挂载点
   - 如果配置需要，重启容器使挂载生效

4. **验证结果**
   - 读取新配置确认挂载成功

### 卸载流程（destroy）

1. 检查容器和挂载点是否存在
2. 删除挂载点配置
3. 如果需要，重启容器使更改生效

## 注意事项

1. **容器状态**：挂载操作可能需要重启容器才能生效，建议设置 `restart_container = true`
2. **路径要求**：宿主机路径必须已存在且可访问
3. **权限要求**：SSH 用户需要有执行 `pct` 命令的权限（通常是 root）
4. **挂载点 ID**：每个容器的挂载点 ID 必须唯一（mp0-mp9）
5. **幂等性**：模块会自动检测现有配置，多次应用相同配置不会产生副作用

## 常见问题

### Q: 挂载后容器内看不到目录？
A: 确保设置了 `restart_container = true`，挂载需要重启容器才能生效。

### Q: 如何挂载多个目录到同一个容器？
A: 创建多个模块实例，每个使用不同的 `mount_point_id`（mp0, mp1, mp2...）。

### Q: 可以在容器运行时挂载吗？
A: 可以，但需要重启容器才能看到挂载点。如果不想影响运行中的服务，可以设置 `restart_container = false`，稍后手动重启。

### Q: 如何更改挂载路径？
A: 直接修改 `host_path` 或 `container_path` 变量，Terraform 会检测到变化并自动更新配置。

## 相关命令

手动操作 LXC 挂载点的命令参考：

```bash
# 查看容器配置
pct config 243

# 添加挂载点
pct set 243 -mp0 /mnt/mydisk,mp=/mnt/mydisk

# 删除挂载点
pct set 243 --delete mp0

# 重启容器
pct restart 243
```
