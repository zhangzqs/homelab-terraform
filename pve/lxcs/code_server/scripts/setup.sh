#!/bin/bash
set -e

echo 'Performing internal LXC configuration...'

# 更换为国内镜像源
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

# 更新系统并安装必要工具
apt-get update && apt-get install -y \
    curl \
    wget \
    openssh-server \
    htop \
    git \
    sudo

# 检查是否已安装code-server
if ! command -v code-server >/dev/null 2>&1; then
    echo "Installing code-server..."

    # 使用官方安装脚本
    curl -fsSL https://code-server.dev/install.sh | sh

    echo "code-server installed successfully."
else
    echo "code-server is already installed."
fi

# 删除官方的systemd service文件，使用自定义配置
echo "Removing official systemd service files..."
rm -f /lib/systemd/system/code-server@.service
rm -f /lib/systemd/user/code-server.service
systemctl daemon-reload

echo "Setup completed. Systemd service will be configured separately."
