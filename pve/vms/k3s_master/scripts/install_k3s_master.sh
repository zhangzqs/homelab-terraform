#!/bin/bash
set -e

echo 'Installing K3s master node...'

# 使用中国镜像安装 K3s
export INSTALL_K3S_MIRROR="cn"
export INSTALL_K3S_EXEC="--disable traefik"
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | sh -

# 等待 K3s 启动
echo 'Waiting for K3s to start...'
sleep 10

# 检查 K3s 状态
systemctl status k3s --no-pager || true

# 安装 Helm
echo 'Installing Helm...'
curl -fsSL https://gh-proxy.org/https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证 Helm 安装
echo 'Verifying Helm installation...'
helm version

echo 'K3s master node and Helm installation completed.'
