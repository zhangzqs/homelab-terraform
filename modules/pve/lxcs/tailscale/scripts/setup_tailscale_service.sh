#!/bin/bash
set -e

# 先停止默认的tailscaled服务
systemctl stop tailscaled.service 2>/dev/null || true
systemctl disable tailscaled.service 2>/dev/null || true

# 安装自定义的systemd服务
cp /tmp/tailscaled.service /etc/systemd/system/tailscaled.service
rm -f /tmp/tailscaled.service

# 创建必要的目录
mkdir -p /var/lib/tailscale

# 重新加载systemd并启动服务
systemctl daemon-reload
systemctl enable tailscaled.service
systemctl start tailscaled.service

# 等待tailscaled启动
sleep 3

# 检查tailscaled状态
systemctl status tailscaled.service --no-pager || true
