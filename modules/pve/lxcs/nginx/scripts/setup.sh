echo 'Performing internal LXC configuration...'
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
sed -i 's/http:/https:/g' /etc/apt/sources.list

apt-get update && apt-get install -y ca-certificates curl openssh-server htop

PACKAGE_VERSION="${nginx_package_version}"
PACKAGE_REPO="${nginx_package_repo}"
PACKAGE_BASE_URL="https://github.com/$${PACKAGE_REPO}/releases/download/v$${PACKAGE_VERSION}"
NGINX_PACKAGE="nginx-vts_$${PACKAGE_VERSION}_ubuntu24.04_amd64.deb"

# 如果已经安装了目标版本且带 VTS 模块则跳过安装步骤
if command -v nginx >/dev/null 2>&1 \
    && nginx -v 2>&1 | grep -q "nginx/$${PACKAGE_VERSION}" \
    && nginx -V 2>&1 | grep -q nginx-module-vts; then
    echo "nginx with VTS is already installed."
else
    echo "Installing nginx-vts package..."
    curl -fsSL -o "/tmp/$${NGINX_PACKAGE}" "$${PACKAGE_BASE_URL}/$${NGINX_PACKAGE}"
    dpkg -i "/tmp/$${NGINX_PACKAGE}" || apt-get -f install -y
    rm -f "/tmp/$${NGINX_PACKAGE}"
fi

# 停止并禁用默认的nginx服务
systemctl stop nginx || true
systemctl disable nginx || true

echo "Setup completed. Directory structure and systemd service will be configured separately."
