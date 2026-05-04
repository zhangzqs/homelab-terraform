#!/bin/bash
set -e

echo "Setting up Tailscale Web service..."

# 部署tailscale-web服务文件
if [ -f /tmp/tailscale-web.service ]; then
    cp /tmp/tailscale-web.service /etc/systemd/system/tailscale-web.service
    rm -f /tmp/tailscale-web.service

    # 重新加载systemd配置
    systemctl daemon-reload

    # 启用并启动服务
    systemctl enable tailscale-web.service
    systemctl restart tailscale-web.service

    # 显示服务状态
    systemctl status tailscale-web.service --no-pager || true

    echo "Tailscale Web service configured and started successfully."
else
    echo "Tailscale Web service file not found, skipping..."
fi
