echo 'Performing internal LXC configuration...'
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

apt-get update && apt-get install -y curl openssh-server htop

# 如果nginx已经安装则跳过安装步骤
if ! command -v nginx >/dev/null 2>&1; then
    echo "Installing nginx..."
    apt-get install -y nginx
else
    echo "nginx is already installed."
fi

# 停止并禁用默认的nginx服务
systemctl stop nginx || true
systemctl disable nginx || true

echo "Setup completed. Directory structure and systemd service will be configured separately."
