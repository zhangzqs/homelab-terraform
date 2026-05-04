# 快速开始

这是一个用于将 PVE 宿主机目录挂载到 LXC 容器的 Terraform 模块。

## 最简使用

```hcl
module "lxc_mount" {
  source = "../utils/lxc_mount_point"

  # SSH 连接到 PVE 宿主机
  ssh_host     = "192.168.1.100"
  ssh_password = "your-password"

  # LXC 容器和挂载配置
  container_id   = 243
  host_path      = "/mnt/hdd-disk"
  container_path = "/mnt/mydisk"
}
```

## 运行 Terraform

```bash
# 初始化模块
terraform init

# 查看计划
terraform plan

# 应用配置
terraform apply

# 销毁资源（会自动卸载挂载点）
terraform destroy
```

## 验证挂载

```bash
# 在 PVE 宿主机上查看容器配置
pct config 243

# 进入容器检查挂载点
pct enter 243
df -h | grep /mnt/mydisk
```

## 幂等性说明

此模块保证了幂等性：
- 多次执行 `terraform apply` 不会重复操作
- 自动检测现有挂载配置
- 只在配置变化时才更新
- 不会因重复应用而重启容器

## 完整文档

查看 [README.md](README.md) 获取详细文档和更多示例。
