#!/bin/bash
set -e

echo 'Performing internal LXC configuration...'
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

apt-get update && apt-get install -y curl openssh-server htop nfs-kernel-server

# 启用并启动NFS服务
systemctl enable nfs-kernel-server
systemctl start nfs-kernel-server

echo "NFS Server setup completed."
