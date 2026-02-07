#!/bin/bash
set -euo pipefail

# 参数
MOUNT_POINT="${mount_point}"
DISK_LABEL="${disk_label}"

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "====== 开始卸载自动磁盘挂载配置 ======"
log "挂载点: $MOUNT_POINT"

# 生成 systemd 单元文件名
SYSTEMD_MOUNT_NAME=$(systemd-escape --path "$MOUNT_POINT").mount
SYSTEMD_AUTOMOUNT_NAME=$(systemd-escape --path "$MOUNT_POINT").automount

log "Systemd mount 单元: $SYSTEMD_MOUNT_NAME"
log "Systemd automount 单元: $SYSTEMD_AUTOMOUNT_NAME"

# 停止并禁用服务
log "停止并禁用服务..."
systemctl stop "$SYSTEMD_AUTOMOUNT_NAME" 2>/dev/null || true
systemctl stop "$SYSTEMD_MOUNT_NAME" 2>/dev/null || true
systemctl disable "$SYSTEMD_AUTOMOUNT_NAME" 2>/dev/null || true
systemctl disable "$SYSTEMD_MOUNT_NAME" 2>/dev/null || true

# 停止并禁用权限设置服务（如果存在）
if [ -f "/etc/systemd/system/set-mount-permissions-$${DISK_LABEL}.service" ]; then
    log "移除权限设置服务..."
    systemctl stop "set-mount-permissions-$${DISK_LABEL}.service" 2>/dev/null || true
    systemctl disable "set-mount-permissions-$${DISK_LABEL}.service" 2>/dev/null || true
    rm -f "/etc/systemd/system/set-mount-permissions-$${DISK_LABEL}.service"
fi

# 删除 systemd 单元文件
log "删除 systemd 单元文件..."
rm -f "/etc/systemd/system/$SYSTEMD_MOUNT_NAME"
rm -f "/etc/systemd/system/$SYSTEMD_AUTOMOUNT_NAME"

# 重新加载 systemd
log "重新加载 systemd 配置..."
systemctl daemon-reload

# 卸载挂载点（如果已挂载）
if mountpoint -q "$MOUNT_POINT"; then
    log "卸载挂载点..."
    umount "$MOUNT_POINT" || log "警告: 无法卸载 $MOUNT_POINT"
fi

# 询问是否删除挂载点目录
log "挂载点目录 $MOUNT_POINT 仍然存在"
log "如需删除，请手动执行: rmdir $MOUNT_POINT"

log "====== 卸载完成 ======"
