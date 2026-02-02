#!/bin/bash
set -e

echo 'Performing internal LXC configuration for Tailscale...'

# 更换为中科大镜像源
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

# 更新并安装基础工具
apt-get update && apt-get install -y curl openssh-server htop wget ca-certificates gnupg

# 检查TUN设备是否可用
if [ ! -e /dev/net/tun ]; then
    echo "ERROR: /dev/net/tun device not found!"
    echo "Please ensure the LXC container has TUN device access configured."
    echo "Add the following to /etc/pve/lxc/[VMID].conf on Proxmox host:"
    echo "  lxc.cgroup2.devices.allow: c 10:200 rwm"
    echo "  lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file"
    exit 1
fi

echo "TUN device found at /dev/net/tun - OK"

# 如果tailscale已经安装则跳过安装步骤
if command -v tailscale >/dev/null 2>&1; then
    echo "Tailscale is already installed."
    tailscale version || true
    exit 0
fi

echo "Installing Tailscale..."

# 添加Tailscale GPG密钥
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# 添加Tailscale仓库
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list

# 更新并安装Tailscale
apt-get update
apt-get install -y tailscale

# 启用IP转发（子网路由需要）
echo "Enabling IP forwarding for subnet routing..."
cat > /etc/sysctl.d/99-tailscale.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF

# 立即应用sysctl配置
sysctl -p /etc/sysctl.d/99-tailscale.conf

echo "Tailscale installation completed successfully."
echo "Tailscale version: $(tailscale version)"
echo "IP forwarding enabled for subnet routing."
