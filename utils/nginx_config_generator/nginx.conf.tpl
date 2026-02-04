user  root;
worker_processes  ${worker_processes};
worker_rlimit_nofile 102400;
timer_resolution 1000ms;

error_log  /dev/stderr warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  ${worker_connections};
    multi_accept on;
    use epoll;
}

http {
    ##
    # Basic Settings
    ##
    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    types_hash_max_size 2048;
    server_tokens   off;
    keepalive_timeout  65;

    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    max_ranges 1;
    server_names_hash_bucket_size 128;
%{ if enable_vts }

    # VTS模块配置
    vhost_traffic_status_zone;
    server {
        listen 0.0.0.0:${vts_status_port};
        server_name localhost;
        location /status {
            vhost_traffic_status_display;
            vhost_traffic_status_display_format html;
        }
    }
%{ endif }
%{ if log_format == "json" }

    log_format json_main escape=json '{'
        # 基础信息
        '"timestamp":"$time_iso8601",'
        '"server_addr":"$server_addr",'
        '"remote_addr":"$remote_addr",'
        '"host":"$host",'
        '"uri":"$uri",'
        '"request":"$request",'
        '"request_method":"$request_method",'
        '"args":"$args",'

        # 响应状态
        '"status":"$status",'
        '"upstream_status":"$upstream_status",'

        # 流量与性能
        '"body_bytes_sent":$body_bytes_sent,'
        '"request_length":$request_length,'
        '"request_time":$request_time,'
        '"upstream_response_time":$upstream_response_time,'
        '"upstream_connect_time":$upstream_connect_time,'

        # 网络与代理
        '"upstream_addr":"$upstream_addr",'
        '"http_x_forwarded_for":"$http_x_forwarded_for",'
        '"http_x_real_ip":"$http_x_real_ip",'

        # 安全与加密
        '"ssl_protocol":"$ssl_protocol",'
        '"ssl_cipher":"$ssl_cipher",'

        # 用户与来源
        '"http_referer":"$http_referer",'
        '"http_user_agent":"$http_user_agent",'
        '"http_cookie":"$http_cookie"'
    '}';

    access_log  /dev/stdout  json_main;
%{ else }

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /dev/stdout  main;
%{ endif }
%{ if enable_gzip }

    gzip  on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;
%{ endif }

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ''      close;
    }

    proxy_cache_path /var/cache/nginx/proxy
        levels=1:2
        keys_zone=proxy_cache:100m
        max_size=10G
        inactive=7d
        use_temp_path=off;
%{ if custom_global_config != "" }

    # 自定义全局配置
${custom_global_config}
%{ endif }

    # 上游服务器配置
    include /etc/nginx/conf.d/upstream.conf;

    # 服务配置
    include /etc/nginx/conf.d/servers.conf;
}
