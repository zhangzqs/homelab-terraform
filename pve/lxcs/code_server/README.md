# Code Server LXC 容器部署

这是一个用于在 Proxmox VE 上部署 code-server 的 Terraform 模板。

## 特性

- 🔒 非特权容器(unprivileged)
- 🌐 静态 IP 配置
- 🔑 自动生成 SSH 密钥对和密码
- 📦 使用官方安装脚本安装 code-server
- 🚀 自定义 systemd service 配置
- 📝 使用配置文件管理所有参数
- 🔧 删除官方 service 文件,避免冲突
- ⚙️ 配置文件和服务分离,易于管理

## 资源配置

- **CPU**: 4 核心
- **内存**: 4GB (无 swap)
- **磁盘**: 20GB
- **网络**: 静态 IP

## 使用方法

### 1. 准备 terraform.tfvars

创建 `terraform.tfvars` 文件:

```hcl
# PVE 节点配置 (common_pve_variables.tf)
pve_node_name = "pve"

# 容器模板
ubuntu_template_file_id = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

# 容器 ID
vm_id = 200

# 网络配置
ipv4_address      = "192.168.1.200"
ipv4_address_cidr = 24
ipv4_gateway      = "192.168.1.1"

# 可选配置
hostname                  = "code-server"
network_interface_bridge  = "vmbr0"
working_dir              = "/root/code-server"
code_server_port         = 8080
# code_server_password   = "your-password"  # 留空自动生成
```

### 2. 部署

```bash
terraform init
terraform plan
terraform apply
```

### 3. 获取访问信息

部署完成后,查看输出信息:

```bash
# 获取容器 IP
terraform output container_ip

# 获取访问地址
terraform output code_server_url

# 获取密码
terraform output -raw code_server_password
```

### 4. 访问 Code Server

在浏览器中打开显示的 URL,使用输出的密码登录。

## 自定义配置

### 修改端口

在 `terraform.tfvars` 中设置:

```hcl
code_server_port = 9090
```

### 使用固定密码

在 `terraform.tfvars` 中设置:

```hcl
code_server_password = "your-secure-password"
```

### 修改资源配置

编辑 `main.tf` 中的资源配置:

```hcl
cpu {
  cores = 2  # 修改 CPU 核心数
}

memory {
  dedicated = 2048  # 修改内存大小(MB)
}

disk {
  datastore_id = "local-lvm"
  size         = 10  # 修改磁盘大小(GB)
}
```

## 注意事项

1. 需要手动指定容器的静态 IP 地址、网关等网络配置
2. 默认使用非特权容器,不需要修改宿主机配置
3. Code Server 默认监听所有接口(0.0.0.0),建议配置防火墙或反向代理
4. 安装时会自动删除官方的 systemd service 文件,使用自定义配置
5. 自定义 service 位于 `/etc/systemd/system/code-server.service`
6. 配置文件位于 `${working_dir}/config.yaml` (默认 `/root/code-server/config.yaml`)
7. 所有配置、数据、日志都集中在 working_dir 目录中

## 日志查看

SSH 登录容器后:

```bash
# 查看服务状态
systemctl status code-server

# 查看日志
journalctl -u code-server -f

# 查看应用日志
tail -f /root/code-server/code-server.log

# 重启服务
systemctl restart code-server

# 查看配置文件
cat /root/code-server/config.yaml

# 修改配置后需要重启服务
vim /root/code-server/config.yaml
systemctl restart code-server
```

## 目录结构

```
/root/code-server/           # working_dir
├── config.yaml              # code-server 配置文件
├── code-server.log          # 应用日志
├── user-data/               # 用户数据目录
│   ├── User/                # VS Code 用户配置
│   ├── extensions/          # 已安装扩展
│   └── ...
└── <your-project-files>     # 项目文件
```

## 自定义配置

### 修改配置文件

编辑 `templates/config.yaml.tpl` 来调整 code-server 配置:

```yaml
bind-addr: 0.0.0.0:8080
auth: password
password: <自动生成>
user-data-dir: /root/code-server/user-data
cert: false
disable-telemetry: true
disable-update-check: true
```

支持的配置项:
- `bind-addr` - 监听地址和端口
- `auth` - 认证方式 (password/none)
- `password` - 登录密码
- `user-data-dir` - 用户数据目录
- `cert` - 是否启用 HTTPS
- `cert-key` - HTTPS 证书密钥路径
- `disable-telemetry` - 禁用遥测
- `disable-update-check` - 禁用更新检查
- `proxy-domain` - 代理域名
- `disable-file-downloads` - 禁用文件下载
- `disable-file-uploads` - 禁用文件上传

### 修改 systemd service

编辑 `templates/code-server.service.tpl`:

```ini
[Service]
Type=simple
User=root
WorkingDirectory=/root/code-server
ExecStart=/usr/bin/code-server --config /root/code-server/config.yaml /root/code-server
Restart=always
RestartSec=5
```

注意:
- systemd service 通过 `--config` 参数指定配置文件路径
- 所有配置都在 config.yaml 中
- 配置文件、用户数据、日志都在同一个 working_dir 下

## 卸载

```bash
terraform destroy
```
