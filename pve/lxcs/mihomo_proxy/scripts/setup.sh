echo 'Performing internal LXC configuration...'
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

apt-get update && apt-get install -y curl openssh-server htop

# 如果mihomo已经安装则跳过安装步骤
if ! command -v mihomo >/dev/null 2>&1; then
    echo "Installing mihomo..."
    wget https://gh-proxy.org/https://github.com/MetaCubeX/mihomo/releases/download/v1.19.19/mihomo-linux-amd64-v2-v1.19.19.deb -O /tmp/mihomo.deb
    dpkg -i /tmp/mihomo.deb
    rm -f /tmp/mihomo.deb
else
    echo "mihomo is already installed."
fi

echo "Setup completed. Systemd service will be configured separately."
