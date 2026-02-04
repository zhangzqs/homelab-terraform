# 测试混合模式：同时使用共享和内联 upstream
run "test_hybrid_mode" {
  command = plan

  variables {
    shared_upstreams = {
      common_backend = {
        servers = [{ address = "192.168.1.100", port = 8080 }]
      }
    }

    services = {
      # 使用共享 upstream
      service_with_shared = {
        upstream_ref = "common_backend"
        domains      = [{ domain = "shared.example.com" }]
      }
      # 使用内联 upstream
      service_with_inline = {
        upstream_inline = {
          servers = [{ address = "192.168.1.200", port = 9000 }]
        }
        domains = [{ domain = "inline.example.com" }]
      }
    }
  }

  assert {
    condition     = can(regex("upstream common_backend", output.upstream_conf))
    error_message = "应该包含共享 upstream"
  }

  assert {
    condition     = can(regex("upstream service_with_inline_upstream", output.upstream_conf))
    error_message = "应该包含自动生成的内联 upstream"
  }

  assert {
    condition     = can(regex("proxy_pass http://common_backend", output.servers_conf))
    error_message = "共享服务应该引用共享 upstream"
  }

  assert {
    condition     = can(regex("proxy_pass http://service_with_inline_upstream", output.servers_conf))
    error_message = "内联服务应该引用自动生成的 upstream"
  }
}

# 测试复杂的混合场景
run "test_complex_hybrid_scenario" {
  command = plan

  variables {
    shared_upstreams = {
      api_cluster = {
        servers = [
          { address = "10.0.0.1", port = 8080 },
          { address = "10.0.0.2", port = 8080 }
        ]
      }
      db_cluster = {
        servers = [
          { address = "10.0.1.1", port = 5432 },
          { address = "10.0.1.2", port = 5432 }
        ]
      }
    }

    services = {
      # API 服务使用共享 API 集群
      api = {
        upstream_ref = "api_cluster"
        domains      = [{ domain = "api.example.com" }]
      }
      # 管理后台也使用 API 集群
      admin = {
        upstream_ref = "api_cluster"
        domains      = [{ domain = "admin.example.com" }]
      }
      # 数据服务使用共享 DB 集群
      data = {
        upstream_ref = "db_cluster"
        domains      = [{ domain = "data.example.com" }]
      }
      # 静态站点使用独立后端
      static = {
        upstream_inline = {
          servers = [{ address = "10.0.2.1", port = 80 }]
        }
        domains = [{ domain = "static.example.com" }]
      }
      # 监控服务使用独立后端
      monitoring = {
        upstream_inline = {
          servers = [{ address = "10.0.3.1", port = 3000 }]
        }
        domains = [{ domain = "monitor.example.com" }]
      }
    }
  }

  assert {
    condition     = length(regexall("upstream api_cluster", output.upstream_conf)) == 1
    error_message = "api_cluster 应该只定义一次"
  }

  assert {
    condition     = length(regexall("upstream db_cluster", output.upstream_conf)) == 1
    error_message = "db_cluster 应该只定义一次"
  }

  assert {
    condition     = can(regex("upstream static_upstream", output.upstream_conf))
    error_message = "应该为 static 服务生成内联 upstream"
  }

  assert {
    condition     = can(regex("upstream monitoring_upstream", output.upstream_conf))
    error_message = "应该为 monitoring 服务生成内联 upstream"
  }

  assert {
    condition     = length(regexall("proxy_pass http://api_cluster", output.servers_conf)) >= 2
    error_message = "api 和 admin 应该共享 api_cluster"
  }
}

# 测试 HTTPS 和高级代理配置
run "test_https_and_proxy_config" {
  command = plan

  variables {
    services = {
      secure_service = {
        upstream_inline = {
          servers = [{ address = "10.0.0.1", port = 443 }]
        }
        domains = [
          {
            domain              = "secure.example.com"
            http_enabled        = false
            https_enabled       = true
            ssl_certificate     = "/etc/nginx/ssl/cert.pem"
            ssl_certificate_key = "/etc/nginx/ssl/key.pem"
          }
        ]
        proxy_config = {
          enable_websocket     = true
          connect_timeout      = "500ms"
          read_timeout         = "2000s"
          send_timeout         = "2000s"
          client_max_body_size = "500M"
          proxy_buffering      = true
        }
      }
    }

    ssl_common_config = {
      protocols             = "TLSv1.3"
      ciphers               = "ECDHE-RSA-AES256-GCM-SHA384"
      prefer_server_ciphers = true
      session_cache         = "shared:SSL:20m"
      session_timeout       = "30m"
    }
  }

  assert {
    condition     = can(regex("listen 443 ssl", output.servers_conf))
    error_message = "应该包含 HTTPS 监听配置"
  }

  assert {
    condition     = can(regex("ssl_certificate /etc/nginx/ssl/cert.pem", output.servers_conf))
    error_message = "应该包含 SSL 证书路径"
  }

  assert {
    condition     = can(regex("ssl_protocols TLSv1.3", output.servers_conf))
    error_message = "应该包含 SSL 协议配置"
  }

  assert {
    condition     = can(regex("proxy_connect_timeout 500ms", output.servers_conf))
    error_message = "应该包含自定义连接超时"
  }

  assert {
    condition     = can(regex("client_max_body_size 500M", output.servers_conf))
    error_message = "应该包含自定义 body 大小限制"
  }

  assert {
    condition     = can(regex("proxy_buffering on", output.servers_conf))
    error_message = "应该启用代理缓冲"
  }
}
