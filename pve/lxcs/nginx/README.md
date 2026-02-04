# Nginx LXC 容器

用于在 Proxmox 上创建和配置 Nginx LXC 容器的 Terraform 模块。

## 功能特性

- 🚀 **自动化部署**：一键创建和配置 Nginx LXC 容器
- 📦 **配置管理**：自动从 nginx_config_generator 模块获取配置并部署
- ⚙️  **自定义 Systemd**：使用自定义的 systemd 服务管理 Nginx
- 🔄 **配置更新**：支持配置变更后自动重新部署
- 🔐 **SSH 密钥认证**：自动生成 ED25519 密钥对
- 🌐 **网络配置**：支持自定义 IP、网关配置
- 📁 **独立配置目录**：配置文件存储在 `/root/nginx/config`，日志存储在 `/root/nginx/logs`

## 使用示例

```hcl
# 1. 生成 Nginx 配置
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  services = {
    myapp = {
      upstream_inline = {
        servers = [{ address = "192.168.1.10", port = 8080 }]
      }
      domains = [
        { domain = "app.example.com", http_enabled = true }
      ]
    }
  }
}

# 2. 创建 Nginx LXC 容器并部署配置
module "nginx" {
  source = "../../pve/lxcs/nginx"

  vm_id                   = 100
  hostname                = "nginx-proxy"
  pve_node_name           = "pve"
  ubuntu_template_file_id = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"

  ipv4_address      = "192.168.1.100"
  ipv4_address_cidr = 24
  ipv4_gateway      = "192.168.1.1"

  nginx_configs = module.nginx_config.all_configs
}

# 3. 输出凭据
output "nginx_ssh_key" {
  value     = module.nginx.ssh_private_key
  sensitive = true
}

output "nginx_password" {
  value     = module.nginx.root_password
  sensitive = true
}
```

## 输入变量

### 必需变量

| 变量名                    | 类型        | 说明                          |
|--------------------------|-------------|------------------------------|
| `vm_id`                  | number      | LXC容器ID                     |
| `ubuntu_template_file_id`| string      | Ubuntu LXC模板文件ID          |
| `ipv4_address`           | string      | 容器IPv4地址                  |
| `ipv4_gateway`           | string      | 容器IPv4网关                  |
| `nginx_configs`          | map(string) | Nginx配置文件映射             |

### 可选变量

| 变量名                      | 类型   | 默认值  | 说明                          |
|----------------------------|--------|---------|------------------------------|
| `pve_node_name`            | string | "pve"   | Proxmox节点名称               |
| `hostname`                 | string | "nginx" | 容器主机名                    |
| `network_interface_bridge` | string | "vmbr0" | 网络接口桥接设备              |
| `ipv4_address_cidr`        | number | 24      | IPv4地址CIDR前缀长度          |

## 输出变量

| 变量名             | 说明                     |
|-------------------|--------------------------|
| `container_id`    | LXC容器的ID              |
| `container_vmid`  | LXC容器的VMID            |
| `container_ip`    | LXC容器的IP地址          |
| `hostname`        | 容器的主机名             |
| `ssh_private_key` | SSH私钥（敏感）          |
| `root_password`   | Root密码（敏感）         |

## 工作流程

1. **创建容器**：自动配置 SSH 密钥和随机密码
2. **setup_nginx**：安装 Nginx 并创建配置目录 `/root/nginx/config` 和日志目录 `/root/nginx/logs`
3. **setup_systemd_service**：部署自定义 systemd 服务，指定使用 `/root/nginx/config/nginx.conf`
4. **deploy_nginx_configs**：上传配置文件到 `/root/nginx/config` 并重启服务

## 容器内目录结构

```
/root/nginx/
├── config/
│   ├── nginx.conf          # 主配置文件
│   └── conf.d/
│       ├── upstream.conf   # upstream配置
│       └── servers.conf    # server配置
└── logs/                   # 日志目录
    ├── access.log          # 访问日志
    └── error.log           # 错误日志
```

## 目录结构

```
pve/lxcs/nginx/
├── main.tf            # 主配置文件
├── variables.tf       # 变量定义
├── versions.tf        # Provider版本
├── output.tf          # 输出定义
├── scripts/
│   └── setup.sh       # 初始化脚本
└── templates/
    └── nginx.service.tpl  # Systemd服务文件模板
```

## License

MIT
