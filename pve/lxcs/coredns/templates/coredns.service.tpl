[Unit]
Description=CoreDNS DNS Server
Documentation=https://coredns.io
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${working_dir}
ExecStart=/usr/bin/coredns -conf ${working_dir}/Corefile -dns.port ${dns_port}
Restart=always
RestartSec=5
LimitNOFILE=1048576
StandardOutput=append:${working_dir}/coredns.log
StandardError=append:${working_dir}/coredns.log

# 安全加固
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
