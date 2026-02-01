#!/bin/bash
set -e

echo 'Installing K3s master node...'

# 使用中国镜像安装 K3s
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -

# 等待 K3s 启动
echo 'Waiting for K3s to start...'
sleep 10

# 检查 K3s 状态
systemctl status k3s --no-pager || true

echo 'K3s master node installation completed.'
