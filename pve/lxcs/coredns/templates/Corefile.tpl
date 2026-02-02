.:53 {
    # 错误日志
    errors

    # 日志记录
    log

    # Prometheus metrics
    prometheus 0.0.0.0:${metrics_port}
%{ if length(hosts) > 0 ~}

    hosts {
%{ for host in hosts ~}
        ${host.ip} ${host.hostname}
%{ endfor ~}
        fallthrough
    }
%{ endif ~}

%{ if length(wildcard_domains) > 0 ~}
%{ for domain in wildcard_domains ~}
    # 泛域名记录 *.${domain.zone} => ${domain.ip}
    template IN ANY ${domain.zone} {
        match "\w*\.(${domain.zone}\.)$"
        answer "{{ .Name }} 3600 IN A ${domain.ip}"
        fallthrough
    }
%{ endfor ~}
%{ endif ~}

    # DNS缓存配置
    cache ${cache_ttl}

    # 重载配置
    reload 10s

    # 上游DNS转发
    forward . ${join(" ", upstream_dns_servers)} {
        policy round_robin
        health_check 5s
        max_fails 3
    }
}
