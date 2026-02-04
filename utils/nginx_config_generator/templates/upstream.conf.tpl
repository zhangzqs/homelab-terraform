# Upstream配置
%{ for name, upstream in upstreams }
upstream ${name} {
%{ for server in upstream.servers ~}
    server ${server.address}%{ if server.weight != 1 } weight=${server.weight}%{ endif }%{ if server.max_fails > 0 } max_fails=${server.max_fails}%{ endif }%{ if server.fail_timeout != "30s" } fail_timeout=${server.fail_timeout}%{ endif }%{ if server.backup } backup%{ endif };
%{ endfor ~}
%{ if upstream.keepalive != null && upstream.keepalive > 0 }
    keepalive ${upstream.keepalive};
%{ endif ~}
%{ if upstream.keepalive_timeout != null && upstream.keepalive_timeout != "60s" }
    keepalive_timeout ${upstream.keepalive_timeout};
%{ endif ~}
}

%{ endfor }
