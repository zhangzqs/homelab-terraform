#!/bin/bash
set -euo pipefail

WORKING_DIR="${working_dir}"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "====== 开始卸载 mihomo ======"

# 停止并禁用服务
log "停止并禁用 mihomo 服务..."
systemctl stop mihomo.service 2>/dev/null || true
systemctl disable mihomo.service 2>/dev/null || true

# 删除 systemd 单元文件
log "删除 systemd 单元文件..."
rm -f /etc/systemd/system/mihomo.service
systemctl daemon-reload

# 卸载 mihomo 包
if command -v mihomo >/dev/null 2>&1; then
    log "卸载 mihomo 软件包..."
    dpkg -r mihomo || true
fi

# 删除工作目录
if [ -d "$WORKING_DIR" ]; then
    log "删除工作目录: $WORKING_DIR"
    rm -rf "$WORKING_DIR"
fi

log "====== mihomo 卸载完成 ======"
