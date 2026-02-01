# Nginx Config Generator

基于 Terraform 的 Nginx 配置生成器模块，用于声明式生成 Nginx 配置文件。

## 设计思路

参考 [home-ansible/templates/nginx](https://github.com/zhangzqs/home-ansiblle/tree/master/templates/nginx) 的设计，将 Jinja2 模板转换为 Terraform 模板，提供：

1. **声明式配置**: 使用 Terraform 变量定义 Nginx 配置
2. **模块化设计**: 分离主配置、upstream、server 配置
3. **类型验证**: 利用 Terraform 的类型系统和验证规则确保配置正确性
4. **灵活扩展**: 支持自定义配置片段

## 功能特性

- 自动生成 `nginx.conf` 主配置文件
- 自动生成 `upstream.conf` 上游服务器配置
- 为每个服务生成独立的 server 配置文件
- 支持 HTTP/HTTPS 双协议
- 支持 WebSocket 代理
- 支持 VTS 流量监控模块
- 支持 JSON 格式访问日志
- 灵活的代理配置（超时、缓冲、Body大小等）

## 使用示例

### 基本用法

```hcl
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  # 基础配置
  worker_processes   = "auto"
  worker_connections = 102400
  enable_vts         = true
  enable_gzip        = true
  log_format         = "json"

  # 定义上游服务器
  upstreams = {
    portainer_nodes = {
      servers = [
        {
          address  = "192.168.1.100"
          port     = 9000
          weight   = 1
        },
        {
          address  = "192.168.1.101"
          port     = 9000
          weight   = 1
        }
      ]
      keepalive = 32
    }

    grafana_nodes = {
      servers = [
        {
          address  = "192.168.1.100"
          port     = 3000
        }
      ]
    }
  }

  # 定义服务
  services = {
    portainer = {
      upstream = "portainer_nodes"
      domains = [
        {
          domain        = "portainer.example.com"
          http_enabled  = true
          https_enabled = false
        }
      ]
    }

    grafana = {
      upstream = "grafana_nodes"
      domains = [
        {
          domain              = "grafana.example.com"
          http_enabled        = false
          https_enabled       = true
          ssl_certificate     = "/etc/nginx/ssl/grafana.crt"
          ssl_certificate_key = "/etc/nginx/ssl/grafana.key"
        }
      ]
      proxy_config = {
        enable_websocket     = true
        client_max_body_size = "100M"
      }
    }
  }

  # SSL通用配置
  ssl_common_config = {
    protocols     = "TLSv1.2 TLSv1.3"
    ciphers       = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
    session_cache = "shared:SSL:10m"
  }
}

# 使用生成的配置
output "nginx_conf" {
  value = module.nginx_config.nginx_conf
}

output "all_configs" {
  value = module.nginx_config.all_configs
}
```

### 高级用法 - 自定义 Location

```hcl
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  upstreams = {
    api_backend = {
      servers = [
        { address = "10.0.0.1", port = 8080 }
      ]
    }
    static_backend = {
      servers = [
        { address = "10.0.0.2", port = 80 }
      ]
    }
  }

  services = {
    my_app = {
      upstream = "api_backend"
      domains = [
        {
          domain       = "app.example.com"
          http_enabled = true
        }
      ]
      locations = [
        {
          path       = "/api"
          proxy_pass = "http://api_backend"
        },
        {
          path       = "/static"
          proxy_pass = "http://static_backend"
        },
        {
          path = "/health"
          custom_config = <<-EOT
            return 200 "OK";
            add_header Content-Type text/plain;
          EOT
        }
      ]
    }
  }
}
```

### 写入配置文件

```hcl
# 使用 local_file 资源写入配置文件
resource "local_file" "nginx_configs" {
  for_each = module.nginx_config.all_configs

  filename = "/etc/nginx/${each.key}"
  content  = each.value
}
```

## 输出说明

- `nginx_conf`: Nginx 主配置文件内容
- `upstream_conf`: Upstream 配置文件内容
- `server_configs`: 各服务的 server 配置（map，key 为服务名）
- `all_configs`: 所有配置文件的完整映射，可直接用于批量写入

## 变量说明

### 基础配置

| 变量名               | 类型     | 默认值   | 说明                        |
|---------------------|---------|---------|----------------------------|
| `worker_processes`  | string  | "auto"  | Worker进程数                |
| `worker_connections`| number  | 102400  | 每个worker的最大连接数         |
| `enable_vts`        | bool    | true    | 是否启用VTS监控模块            |
| `vts_status_port`   | number  | 80      | VTS监控端口                  |
| `enable_gzip`       | bool    | true    | 是否启用gzip压缩              |
| `log_format`        | string  | "json"  | 日志格式（json/standard）     |

### Upstream 配置

```hcl
upstreams = {
  backend_name = {
    servers = [
      {
        address      = "IP地址"
        port         = 端口号
        max_fails    = 最大失败次数（默认3）
        fail_timeout = 失败超时（默认"30s"）
        weight       = 权重（默认1）
        backup       = 是否备份服务器（默认false）
      }
    ]
    keepalive         = Keepalive连接数（可选）
    keepalive_timeout = Keepalive超时（可选）
  }
}
```

### Service 配置

```hcl
services = {
  service_name = {
    upstream = "对应的upstream名称"
    domains = [
      {
        domain              = "域名"
        http_enabled        = 是否启用HTTP
        https_enabled       = 是否启用HTTPS
        ssl_certificate     = SSL证书路径（https时需要）
        ssl_certificate_key = SSL密钥路径（https时需要）
      }
    ]
    locations = [...]  # 可选，自定义location配置
    proxy_config = {
      enable_websocket     = 是否启用WebSocket
      connect_timeout      = 连接超时
      read_timeout         = 读取超时
      send_timeout         = 发送超时
      client_max_body_size = 请求Body大小限制
      proxy_buffering      = 是否启用代理缓冲
    }
    custom_server_config = "自定义server配置片段"
  }
}
```

## 目录结构

```
utils/nginx_config_generator/
├── variables.tf          # 输入变量定义
├── output.tf            # 输出定义和配置生成逻辑
├── nginx.conf.tpl       # Nginx主配置模板
├── upstream.conf.tpl    # Upstream配置模板
├── server.conf.tpl      # Server配置模板
└── README.md           # 文档
```

## 与 Ansible 版本的对比

| 特性 | Ansible (Jinja2) | Terraform (HCL) |
|-----|------------------|-----------------|
| 模板语言 | Jinja2 | Terraform Template |
| 变量定义 | YAML | HCL |
| 类型检查 | 无 | 强类型+验证规则 |
| 状态管理 | 无 | Terraform State |
| 幂等性 | Ansible保证 | Terraform保证 |
| 使用场景 | 配置管理 | 基础设施即代码 |

## 注意事项

1. 确保服务引用的 `upstream` 在 `upstreams` 变量中已定义
2. HTTPS 配置需要提供有效的 SSL 证书路径
3. 端口号必须在 1-65535 范围内
4. 所有文件路径应使用绝对路径
5. 生成的配置文件需要与实际的 Nginx 模块支持匹配（如 VTS 模块）

## 扩展

可以通过以下方式扩展功能：

1. **自定义全局配置**: 使用 `custom_global_config` 变量
2. **自定义服务配置**: 使用 `custom_server_config` 字段
3. **自定义 Location**: 在 `locations` 中使用 `custom_config` 字段

## License

MIT
