[Unit]
Description=Tailscale Web Interface (Read-only with Metrics)
Documentation=https://tailscale.com/kb/
After=tailscaled.service
Requires=tailscaled.service

[Service]
Type=simple
ExecStart=/usr/bin/tailscale web --readonly --listen 0.0.0.0:${metrics_port}
Restart=on-failure
RestartSec=5

# 安全加固
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true

[Install]
WantedBy=multi-user.target
