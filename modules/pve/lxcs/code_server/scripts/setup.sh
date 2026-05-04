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
    sudo \
    jq

echo "Basic setup completed. Use install-code-server.sh to install code-server separately."
