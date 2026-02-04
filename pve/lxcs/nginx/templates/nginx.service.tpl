[Unit]
Description=The NGINX HTTP and reverse proxy server
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -c /root/nginx/config/nginx.conf
ExecStart=/usr/sbin/nginx -c /root/nginx/config/nginx.conf
ExecReload=/bin/sh -c "/bin/kill -s HUP $(/bin/cat /run/nginx.pid)"
ExecStop=/bin/sh -c "/bin/kill -s TERM $(/bin/cat /run/nginx.pid)"
TimeoutStopSec=5
KillMode=mixed
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
