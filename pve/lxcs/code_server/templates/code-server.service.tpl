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
StandardOutput=append:${working_dir}/code-server.log
StandardError=append:${working_dir}/code-server.log

[Install]
WantedBy=multi-user.target
