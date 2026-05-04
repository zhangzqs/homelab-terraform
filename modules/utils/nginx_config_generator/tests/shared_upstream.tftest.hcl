# 测试共享 upstream 配置方式
run "test_shared_upstream" {
  command = plan

  variables {
    shared_upstreams = {
      backend_cluster = {
        servers = [
          { address = "192.168.1.10", port = 8080 },
          { address = "192.168.1.11", port = 8080 }
        ]
        keepalive = 32
      }
    }

    services = {
      web_service = {
        upstream_ref = "backend_cluster"
        domains = [
          { domain = "web.example.com", http_enabled = true }
        ]
      }
    }
  }

  assert {
    condition     = can(regex("upstream backend_cluster", output.upstream_conf))
    error_message = "upstream.conf 应该包含共享 upstream 名称"
  }

  assert {
    condition     = can(regex("server 192.168.1.10:8080", output.upstream_conf))
    error_message = "应该包含第一个服务器地址"
  }

  assert {
    condition     = can(regex("server 192.168.1.11:8080", output.upstream_conf))
    error_message = "应该包含第二个服务器地址"
  }

  assert {
    condition     = can(regex("proxy_pass http://backend_cluster", output.servers_conf))
    error_message = "server 配置应该引用正确的 upstream"
  }
}

# 测试多个服务共享同一个 upstream
run "test_multiple_services_sharing_upstream" {
  command = plan

  variables {
    shared_upstreams = {
      shared_backend = {
        servers = [{ address = "10.0.0.100", port = 9000 }]
      }
    }

    services = {
      api = {
        upstream_ref = "shared_backend"
        domains      = [{ domain = "api.example.com" }]
      }
      admin = {
        upstream_ref = "shared_backend"
        domains      = [{ domain = "admin.example.com" }]
      }
      portal = {
        upstream_ref = "shared_backend"
        domains      = [{ domain = "portal.example.com" }]
      }
    }
  }

  assert {
    condition     = length(regexall("upstream shared_backend", output.upstream_conf)) == 1
    error_message = "shared_backend 应该只定义一次"
  }

  assert {
    condition     = can(regex("server_name api.example.com", output.servers_conf))
    error_message = "应该包含 api 服务配置"
  }

  assert {
    condition     = can(regex("server_name admin.example.com", output.servers_conf))
    error_message = "应该包含 admin 服务配置"
  }

  assert {
    condition     = can(regex("server_name portal.example.com", output.servers_conf))
    error_message = "应该包含 portal 服务配置"
  }

  assert {
    condition     = length(regexall("proxy_pass http://shared_backend", output.servers_conf)) >= 3
    error_message = "三个服务都应该引用 shared_backend"
  }
}

# 测试共享 upstream 的高级配置
run "test_shared_upstream_advanced" {
  command = plan

  variables {
    shared_upstreams = {
      ha_cluster = {
        servers = [
          { address = "10.0.1.1", port = 8080, weight = 3, max_fails = 2, fail_timeout = "10s" },
          { address = "10.0.1.2", port = 8080, weight = 2, max_fails = 2, fail_timeout = "10s" },
          { address = "10.0.1.3", port = 8080, weight = 1, backup = true }
        ]
        keepalive         = 128
        keepalive_timeout = "120s"
      }
    }

    services = {
      ha_service = {
        upstream_ref = "ha_cluster"
        domains      = [{ domain = "ha.example.com" }]
      }
    }
  }

  assert {
    condition     = can(regex("weight=3", output.upstream_conf))
    error_message = "应该包含权重配置"
  }

  assert {
    condition     = can(regex("max_fails=2", output.upstream_conf))
    error_message = "应该包含最大失败次数配置"
  }

  assert {
    condition     = can(regex("fail_timeout=10s", output.upstream_conf))
    error_message = "应该包含失败超时配置"
  }

  assert {
    condition     = can(regex("keepalive 128", output.upstream_conf))
    error_message = "应该包含 keepalive 连接数配置"
  }

  assert {
    condition     = can(regex("keepalive_timeout 120s", output.upstream_conf))
    error_message = "应该包含 keepalive 超时配置"
  }
}
