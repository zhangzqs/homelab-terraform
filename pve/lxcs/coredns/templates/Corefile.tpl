. {
    # 监听配置 - UDP和TCP同时启用
    bind 0.0.0.0

    # 日志记录
    log {
        class all
    }

    # 错误日志
    errors

    # Prometheus metrics
    prometheus 0.0.0.0:${metrics_port}

    # DNS缓存配置
    cache {
        success ${cache_ttl}
        denial ${cache_ttl}
        prefetch ${cache_prefetch}
        serve_stale ${cache_serve_stale}s
    }
%{ if enable_dnssec ~}

    # DNSSEC验证
    dnssec
%{ endif ~}
%{ if length(custom_hosts) > 0 ~}

    # 自定义hosts记录
    hosts {
%{ for host in custom_hosts ~}
        ${host.ip} ${host.hostname}
%{ endfor ~}
        fallthrough
    }
%{ endif ~}

    # 上游DNS转发
    forward . ${join(" ", upstream_dns_servers)} {
        policy round_robin
        health_check 5s
        max_fails 3
    }

    # 重载配置
    reload 10s
}
