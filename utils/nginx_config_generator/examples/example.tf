# Nginx Config Generator 使用示例

module "nginx_config" {
  source = "."

  # 基础配置
  worker_processes   = "auto"
  worker_connections = 102400
  enable_vts         = true
  vts_status_port    = 80
  enable_gzip        = true
  log_format         = "json"

  # 定义上游服务器
  upstreams = {
    portainer_nodes = {
      servers = [
        {
          address    = "192.168.1.100"
          port       = 9000
          max_fails  = 3
          weight     = 1
        }
      ]
      keepalive = 32
    }

    grafana_nodes = {
      servers = [
        {
          address    = "192.168.1.100"
          port       = 3000
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
      proxy_config = {
        enable_websocket     = true
        client_max_body_size = "8192M"
      }
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
    protocols               = "TLSv1.2 TLSv1.3"
    ciphers                 = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
    prefer_server_ciphers   = true
    session_cache           = "shared:SSL:10m"
    session_timeout         = "10m"
  }
}

# 输出生成的配置
output "nginx_conf" {
  description = "Nginx主配置文件"
  value       = module.nginx_config.nginx_conf
}

output "upstream_conf" {
  description = "Upstream配置文件"
  value       = module.nginx_config.upstream_conf
}

output "server_configs" {
  description = "各服务的server配置"
  value       = module.nginx_config.server_configs
}

output "all_configs" {
  description = "所有配置文件映射"
  value       = module.nginx_config.all_configs
}
