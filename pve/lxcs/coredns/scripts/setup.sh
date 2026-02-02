#!/bin/bash
set -e

echo 'Performing internal LXC configuration...'

# 更换为中科大镜像源
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

apt-get update && apt-get install -y curl openssh-server htop wget

# CoreDNS版本
COREDNS_VERSION="1.12.1"

# 如果coredns已经安装则跳过安装步骤
if ! command -v coredns >/dev/null 2>&1; then
    echo "Installing CoreDNS v${COREDNS_VERSION}..."
    
    # 下载CoreDNS
    wget "https://gh-proxy.org/https://github.com/coredns/coredns/releases/download/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz" -O /tmp/coredns.tgz
    
    # 解压并安装
    tar -xzf /tmp/coredns.tgz -C /tmp
    mv /tmp/coredns /usr/bin/coredns
    chmod +x /usr/bin/coredns
    
    # 清理
    rm -f /tmp/coredns.tgz
    
    echo "CoreDNS installed successfully."
else
    echo "CoreDNS is already installed."
    coredns -version || true
fi

echo "Setup completed. Systemd service will be configured separately."
