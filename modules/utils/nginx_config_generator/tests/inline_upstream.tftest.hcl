# 测试内联 upstream 配置方式
run "test_inline_upstream" {
  command = plan

  variables {
    worker_processes   = "auto"
    worker_connections = 102400

    services = {
      test_service = {
        upstream_inline = {
          servers = [
            {
              address = "192.168.1.100"
              port    = 8080
            }
          ]
          keepalive = 32
        }
        domains = [
          {
            domain       = "test.example.com"
            http_enabled = true
          }
        ]
      }
    }
  }

  # 验证输出
  assert {
    condition     = length(output.all_configs) == 3
    error_message = "应该生成 3 个配置文件（nginx.conf, upstream.conf, servers.conf）"
  }

  assert {
    condition     = can(regex("upstream test_service_upstream", output.upstream_conf))
    error_message = "upstream.conf 应该包含自动生成的 upstream 名称"
  }

  assert {
    condition     = can(regex("server 192.168.1.100:8080", output.upstream_conf))
    error_message = "upstream.conf 应该包含正确的服务器地址"
  }

  assert {
    condition     = can(regex("server_name test.example.com", output.servers_conf))
    error_message = "servers.conf 应该包含正确的域名"
  }

  assert {
    condition     = can(regex("listen 80", output.servers_conf))
    error_message = "servers.conf 应该包含 HTTP 监听端口"
  }
}

# 测试多个内联 upstream
run "test_multiple_inline_upstreams" {
  command = plan

  variables {
    services = {
      service_a = {
        upstream_inline = {
          servers = [{ address = "10.0.0.1", port = 3000 }]
        }
        domains = [{ domain = "a.example.com" }]
      }
      service_b = {
        upstream_inline = {
          servers = [{ address = "10.0.0.2", port = 4000 }]
        }
        domains = [{ domain = "b.example.com" }]
      }
    }
  }

  assert {
    condition     = can(regex("upstream service_a_upstream", output.upstream_conf))
    error_message = "应该生成 service_a_upstream"
  }

  assert {
    condition     = can(regex("upstream service_b_upstream", output.upstream_conf))
    error_message = "应该生成 service_b_upstream"
  }

  assert {
    condition     = can(regex("server_name a.example.com", output.servers_conf))
    error_message = "应该包含 a.example.com 的配置"
  }

  assert {
    condition     = can(regex("server_name b.example.com", output.servers_conf))
    error_message = "应该包含 b.example.com 的配置"
  }
}

# 测试负载均衡配置
run "test_load_balancing" {
  command = plan

  variables {
    services = {
      lb_service = {
        upstream_inline = {
          servers = [
            { address = "10.0.0.1", port = 8080, weight = 2 },
            { address = "10.0.0.2", port = 8080, weight = 1 },
            { address = "10.0.0.3", port = 8080, backup = true }
          ]
          keepalive = 64
        }
        domains = [{ domain = "lb.example.com" }]
      }
    }
  }

  assert {
    condition     = can(regex("weight=2", output.upstream_conf))
    error_message = "应该包含权重配置"
  }

  assert {
    condition     = can(regex("backup", output.upstream_conf))
    error_message = "应该包含备份服务器配置"
  }

  assert {
    condition     = can(regex("keepalive 64", output.upstream_conf))
    error_message = "应该包含 keepalive 配置"
  }
}
