#!/bin/bash
set -euo pipefail

MIHOMO_DOWNLOAD_URL="${mihomo_download_url}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "====== 开始安装 mihomo ======"

# 配置 apt 镜像（Ubuntu）
if [ -f /etc/apt/sources.list ]; then
    sed -i 's@//.*.archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
    sed -i 's/http:/https:/g' /etc/apt/sources.list
fi

apt-get update && apt-get install -y curl openssh-server htop

# 透明代理网关需要 IP 转发，写到 /etc/sysctl.d/ 持久化
cat > /etc/sysctl.d/99-mihomo-gateway.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system >/dev/null

# 安装 mihomo（如果尚未安装）
if ! command -v mihomo >/dev/null 2>&1; then
    log "正在下载并安装 mihomo..."
    wget "$MIHOMO_DOWNLOAD_URL" -O /tmp/mihomo.deb
    dpkg -i /tmp/mihomo.deb
    rm -f /tmp/mihomo.deb
else
    log "mihomo 已安装，跳过安装步骤"
fi

log "====== mihomo 安装完成 ======"
