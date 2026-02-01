[Unit]
Description=Mihomo Proxy Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${working_dir}
ExecStart=/usr/bin/mihomo -d ${working_dir} -f ${working_dir}/config.yaml
Restart=always
RestartSec=5
StandardOutput=append:${working_dir}/mihomo.log
StandardError=append:${working_dir}/mihomo.log

[Install]
WantedBy=multi-user.target
