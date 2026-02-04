# Nginx Config Generator

基于 Terraform 的 Nginx 配置生成器模块，用于声明式生成 Nginx 配置文件。

## 设计思路

参考 [home-ansible/templates/nginx](https://github.com/zhangzqs/home-ansiblle/tree/master/templates/nginx) 的设计，将 Jinja2 模板转换为 Terraform 模板，提供：

1. **声明式配置**: 使用 Terraform 变量定义 Nginx 配置
2. **模块化设计**: 支持内联和共享两种 upstream 配置方式
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

### 方式1：内联 Upstream（推荐）

适合大多数场景，每个服务独立配置自己的后端：

```hcl
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  # 基础配置
  worker_processes   = "auto"
  worker_connections = 102400
  enable_vts         = true
  enable_gzip        = true
  log_format         = "json"

  # 定义服务（upstream配置内联）
  services = {
    grafana = {
      # 直接在服务内定义upstream
      upstream_inline = {
        servers = [
          {
            address = "192.168.1.100"
            port    = 3000
          }
        ]
        keepalive = 32
      }
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

    portainer = {
      upstream_inline = {
        servers = [
          {
            address = "192.168.1.100"
            port    = 9000
            weight  = 1
          },
          {
            address = "192.168.1.101"
            port    = 9000
            weight  = 1
          }
        ]
      }
      domains = [
        {
          domain       = "portainer.example.com"
          http_enabled = true
        }
      ]
    }
  }

  # SSL通用配置
  ssl_common_config = {
    protocols     = "TLSv1.2 TLSv1.3"
    ciphers       = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
    session_cache = "shared:SSL:10m"
  }
}
```

### 方式2：共享 Upstream

适合多个服务需要共享同一个后端的场景：

```hcl
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  # 定义共享的upstream（可被多个服务引用）
  shared_upstreams = {
    portainer_cluster = {
      servers = [
        { address = "192.168.1.100", port = 9000, weight = 1 },
        { address = "192.168.1.101", port = 9000, weight = 1 }
      ]
      keepalive = 32
    }
  }

  # 多个服务引用同一个upstream
  services = {
    portainer_api = {
      upstream_ref = "portainer_cluster"  # 引用共享upstream
      domains = [
        { domain = "api.portainer.example.com", http_enabled = true }
      ]
    }

    portainer_web = {
      upstream_ref = "portainer_cluster"  # 多个服务共享
      domains = [
        { domain = "portainer.example.com", http_enabled = true }
      ]
    }
  }
}
```

### 方式3：混合模式

同时使用共享和内联 upstream：

```hcl
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  # 定义共享upstream
  shared_upstreams = {
    common_backend = {
      servers = [{ address = "192.168.1.100", port = 8080 }]
    }
  }

  services = {
    # 使用共享upstream
    service_a = {
      upstream_ref = "common_backend"
      domains      = [{ domain = "a.example.com" }]
    }

    # 使用内联upstream
    service_b = {
      upstream_inline = {
        servers = [{ address = "192.168.1.200", port = 3000 }]
      }
      domains = [{ domain = "b.example.com" }]
    }
  }
}
```

### 高级用法 - 自定义 Location

```hcl
module "nginx_config" {
  source = "../../utils/nginx_config_generator"

  shared_upstreams = {
    api_backend = {
      servers = [{ address = "10.0.0.1", port = 8080 }]
    }
    static_backend = {
      servers = [{ address = "10.0.0.2", port = 80 }]
    }
  }

  services = {
    my_app = {
      upstream_ref = "api_backend"
      domains = [
        { domain = "app.example.com", http_enabled = true }
      ]
      locations = [
        {
          path       = "/api"
          proxy_pass = "http://api_backend"
        },
        {
          path       = "/static"
          proxy_pass = "http://static_backend"
        }
      ]
    }
  }
}
```

### 使用生成的配置

```hcl
# 输出配置内容
output "nginx_conf" {
  value = module.nginx_config.nginx_conf
}

output "all_configs" {
  value = module.nginx_config.all_configs
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

# 输出示例：
# /etc/nginx/nginx.conf           - 主配置
# /etc/nginx/conf.d/upstream.conf - Upstream配置
# /etc/nginx/conf.d/servers.conf  - 所有服务的Server配置（合并）
```

## 输出说明

- `nginx_conf`: Nginx 主配置文件内容
- `upstream_conf`: Upstream 配置文件内容
- `servers_conf`: 所有服务的 server 配置合并后的内容（单个文件）
- `server_configs`: 各服务的 server 配置（map，key 为服务名，用于需要分离文件的场景）
- `all_configs`: 所有配置文件的完整映射，可直接用于批量写入

## 变量说明

### 基础配置

| 变量名               | 类型   | 默认值                      | 说明                      |
| -------------------- | ------ | --------------------------- | ------------------------- |
| `worker_processes`   | string | "auto"                      | Worker进程数              |
| `worker_connections` | number | 102400                      | 每个worker的最大连接数    |
| `enable_vts`         | bool   | true                        | 是否启用VTS监控模块       |
| `vts_status_port`    | number | 80                          | VTS监控端口               |
| `enable_gzip`        | bool   | true                        | 是否启用gzip压缩          |
| `log_format`         | string | "json"                      | 日志格式（json/standard） |
| `access_log_path`    | string | "/var/log/nginx/access.log" | 访问日志文件路径          |
| `error_log_path`     | string | "/var/log/nginx/error.log"  | 错误日志文件路径          |
| `error_log_level`    | string | "warn"                      | 错误日志级别              |

### Upstream 配置

#### 共享 Upstream (shared_upstreams)

```hcl
shared_upstreams = {
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
    keepalive         = Keepalive连接数（可选，默认32）
    keepalive_timeout = Keepalive超时（可选，默认"60s"）
  }
}
```

### Service 配置

每个服务必须指定 `upstream_ref` 或 `upstream_inline` 之一（二选一）：

```hcl
services = {
  service_name = {
    # 方式1: 引用共享upstream
    upstream_ref = "共享upstream名称"

    # 方式2: 内联upstream配置（与upstream_ref二选一）
    upstream_inline = {
      servers = [...]  # 格式同shared_upstreams
      keepalive = 32
      keepalive_timeout = "60s"
    }

    # 域名配置
    domains = [
      {
        domain              = "域名"
        http_enabled        = 是否启用HTTP（默认true）
        https_enabled       = 是否启用HTTPS（默认false）
        ssl_certificate     = SSL证书路径（https时需要）
        ssl_certificate_key = SSL密钥路径（https时需要）
      }
    ]

    # Location配置（可选）
    locations = [...]

    # 代理配置（可选）
    proxy_config = {
      enable_websocket     = 是否启用WebSocket（默认true）
      connect_timeout      = 连接超时（默认"200ms"）
      read_timeout         = 读取超时（默认"1000s"）
      send_timeout         = 发送超时（默认"1000s"）
      client_max_body_size = 请求Body大小限制（默认"8192M"）
      proxy_buffering      = 是否启用代理缓冲（默认false）
    }
  }
}
```

## 目录结构

```text
utils/nginx_config_generator/
├── variables.tf          # 输入变量定义
├── output.tf            # 输出定义和配置生成逻辑
├── templates/           # 模板文件目录
│   ├── nginx.conf.tpl   # Nginx主配置模板
│   ├── upstream.conf.tpl # Upstream配置模板
│   └── server.conf.tpl  # Server配置模板
├── tests/               # 测试文件目录
│   ├── inline_upstream.tftest.hcl
│   ├── shared_upstream.tftest.hcl
│   ├── hybrid_mode.tftest.hcl
│   └── run_tests.sh     # 测试运行脚本
└── README.md           # 文档
```

## 生成的配置文件结构

```text
/etc/nginx/
├── nginx.conf                # 主配置文件
└── conf.d/
    ├── upstream.conf         # Upstream配置
    └── servers.conf          # 所有服务的Server配置（合并）
```

## 与 Ansible 版本的对比

| 特性         | Ansible (Jinja2) | Terraform (HCL)    |
| ------------ | ---------------- | ------------------ |
| 模板语言     | Jinja2           | Terraform Template |
| 变量定义     | YAML             | HCL                |
| Upstream配置 | 分离式           | 内联+共享两种模式  |
| 类型检查     | 无               | 强类型+验证规则    |
| 状态管理     | 无               | Terraform State    |
| 幂等性       | Ansible保证      | Terraform保证      |
| 使用场景     | 配置管理         | 基础设施即代码     |

## 注意事项

1. 每个服务必须指定 `upstream_ref` 或 `upstream_inline` 之一（二选一）
2. 使用 `upstream_ref` 时，引用的 upstream 必须在 `shared_upstreams` 中定义
3. HTTPS 配置需要提供有效的 SSL 证书路径
4. 端口号必须在 1-65535 范围内
5. 所有文件路径应使用绝对路径
6. 生成的配置文件需要与实际的 Nginx 模块支持匹配（如 VTS 模块）

## 配置选择建议

- **使用内联 upstream**：服务独占后端，配置简单直观
- **使用共享 upstream**：多个服务共享同一个后端集群
- **混合使用**：根据实际需求灵活组合

## License

MIT
