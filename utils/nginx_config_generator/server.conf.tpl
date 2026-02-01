%{ for domain in domains ~}
%{ if domain.http_enabled }
# HTTP服务器配置 - ${service_name} - ${domain.domain}
server {
    listen 80;
    server_name ${domain.domain};
%{ if length(locations) > 0 }
%{ for location in locations ~}

    location ${location.path} {
%{ if location.proxy_pass != "" }
        proxy_pass ${location.proxy_pass};
%{ else }
        proxy_pass http://${upstream};
%{ endif }
%{ if location.custom_config != "" }
${location.custom_config}
%{ else }

        # WebSocket支持
%{ if proxy_config.enable_websocket }
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
%{ endif }

        # 设置代理头部
        proxy_set_header Host $host;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 代理超时配置
        proxy_connect_timeout ${proxy_config.connect_timeout};
        proxy_read_timeout ${proxy_config.read_timeout};
        proxy_send_timeout ${proxy_config.send_timeout};

        # Body大小限制
        client_max_body_size ${proxy_config.client_max_body_size};
%{ if proxy_config.proxy_buffering != null }

        # 代理缓冲配置
        proxy_buffering ${ proxy_config.proxy_buffering ? "on" : "off" };
%{ endif }
%{ endif }
    }
%{ endfor ~}
%{ else }

    location / {
        proxy_pass http://${upstream};

        # WebSocket支持
%{ if proxy_config.enable_websocket }
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
%{ endif }

        # 设置代理头部
        proxy_set_header Host $host;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 代理超时配置
        proxy_connect_timeout ${proxy_config.connect_timeout};
        proxy_read_timeout ${proxy_config.read_timeout};
        proxy_send_timeout ${proxy_config.send_timeout};

        # Body大小限制
        client_max_body_size ${proxy_config.client_max_body_size};
%{ if proxy_config.proxy_buffering != null }

        # 代理缓冲配置
        proxy_buffering ${ proxy_config.proxy_buffering ? "on" : "off" };
%{ endif }
    }
%{ endif }
%{ if custom_server_config != "" }

    # 自定义服务器配置
${custom_server_config}
%{ endif }
}
%{ endif }

%{ if domain.https_enabled }
# HTTPS服务器配置 - ${service_name} - ${domain.domain}
server {
    listen 443 ssl;
    server_name ${domain.domain};

    # SSL证书配置
    ssl_certificate ${domain.ssl_certificate};
    ssl_certificate_key ${domain.ssl_certificate_key};

    # SSL通用配置
    ssl_protocols ${ssl_protocols};
    ssl_ciphers ${ssl_ciphers};
    ssl_prefer_server_ciphers ${ ssl_prefer_server_ciphers ? "on" : "off" };
    ssl_session_cache ${ssl_session_cache};
    ssl_session_timeout ${ssl_session_timeout};
%{ if length(locations) > 0 }
%{ for location in locations ~}

    location ${location.path} {
%{ if location.proxy_pass != "" }
        proxy_pass ${location.proxy_pass};
%{ else }
        proxy_pass http://${upstream};
%{ endif }
%{ if location.custom_config != "" }
${location.custom_config}
%{ else }

        # WebSocket支持
%{ if proxy_config.enable_websocket }
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
%{ endif }

        # 设置代理头部
        proxy_set_header Host $host;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 代理超时配置
        proxy_connect_timeout ${proxy_config.connect_timeout};
        proxy_read_timeout ${proxy_config.read_timeout};
        proxy_send_timeout ${proxy_config.send_timeout};

        # Body大小限制
        client_max_body_size ${proxy_config.client_max_body_size};
%{ if proxy_config.proxy_buffering != null }

        # 代理缓冲配置
        proxy_buffering ${ proxy_config.proxy_buffering ? "on" : "off" };
%{ endif }
%{ endif }
    }
%{ endfor ~}
%{ else }

    location / {
        proxy_pass http://${upstream};

        # WebSocket支持
%{ if proxy_config.enable_websocket }
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
%{ endif }

        # 设置代理头部
        proxy_set_header Host $host;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 代理超时配置
        proxy_connect_timeout ${proxy_config.connect_timeout};
        proxy_read_timeout ${proxy_config.read_timeout};
        proxy_send_timeout ${proxy_config.send_timeout};

        # Body大小限制
        client_max_body_size ${proxy_config.client_max_body_size};
%{ if proxy_config.proxy_buffering != null }

        # 代理缓冲配置
        proxy_buffering ${ proxy_config.proxy_buffering ? "on" : "off" };
%{ endif }
    }
%{ endif }
%{ if custom_server_config != "" }

    # 自定义服务器配置
${custom_server_config}
%{ endif }
}
%{ endif }

%{ endfor ~}
