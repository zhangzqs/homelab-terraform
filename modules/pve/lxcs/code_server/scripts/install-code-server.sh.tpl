#!/bin/bash
set -e

echo "Installing code-server..."

# 设置代理（如果提供）
%{ if has_proxy ~}
export http_proxy="${http_proxy}"
export https_proxy="${https_proxy}"
echo "Using HTTP proxy: ${http_proxy}"
echo "Using HTTPS proxy: ${https_proxy}"
%{ else ~}
echo "No proxy configured."
%{ endif ~}

# 检查是否已安装code-server
if command -v code-server >/dev/null 2>&1; then
    echo "code-server is already installed."
    code-server --version
    exit 0
fi

# 使用官方安装脚本
echo "Downloading and running official install script..."
curl -fsSL https://code-server.dev/install.sh | sh

# 验证安装
if command -v code-server >/dev/null 2>&1; then
    echo "code-server installed successfully."
    code-server --version
else
    echo "ERROR: code-server installation failed!"
    exit 1
fi

# 删除官方的systemd service文件，使用自定义配置
echo "Removing official systemd service files..."
rm -f /lib/systemd/system/code-server@.service
rm -f /lib/systemd/user/code-server.service
systemctl daemon-reload

echo "code-server installation completed."
