[Unit]
Description=Code Server - VS Code in Browser
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${working_dir}
ExecStart=/usr/bin/code-server --config ${working_dir}/config.yaml ${working_dir}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=code-server

[Install]
WantedBy=multi-user.target
