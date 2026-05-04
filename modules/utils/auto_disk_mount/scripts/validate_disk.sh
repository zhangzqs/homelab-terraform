#!/bin/bash
set -euo pipefail

# 参数
DISK_UUID="${disk_uuid}"
MOUNT_POINT="${mount_point}"

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "====== 验证磁盘配置 ======"

# 1. 检查磁盘是否存在
log "检查磁盘 UUID: $DISK_UUID"
if [ ! -e "/dev/disk/by-uuid/$DISK_UUID" ]; then
    log "错误: 找不到 UUID 为 $DISK_UUID 的磁盘"
    log "当前系统中的磁盘列表:"
    lsblk -o NAME,UUID,FSTYPE,SIZE,MOUNTPOINT
    exit 1
fi

log "✓ 磁盘存在"

# 2. 检查磁盘是否已挂载到其他位置
CURRENT_MOUNT=$(findmnt -n -o TARGET --source "/dev/disk/by-uuid/$DISK_UUID" 2>/dev/null || true)
if [ -n "$CURRENT_MOUNT" ] && [ "$CURRENT_MOUNT" != "$MOUNT_POINT" ]; then
    log "警告: 磁盘已挂载到其他位置: $CURRENT_MOUNT"
    log "将尝试卸载..."
    umount "$CURRENT_MOUNT" || {
        log "错误: 无法卸载 $CURRENT_MOUNT"
        exit 1
    }
    log "✓ 已卸载旧的挂载点"
fi

# 3. 检查挂载点是否被其他设备使用
if mountpoint -q "$MOUNT_POINT"; then
    MOUNTED_DEV=$(findmnt -n -o SOURCE --target "$MOUNT_POINT" 2>/dev/null || true)
    if [ -n "$MOUNTED_DEV" ]; then
        log "警告: 挂载点 $MOUNT_POINT 已被其他设备使用: $MOUNTED_DEV"
        log "将尝试卸载..."
        umount "$MOUNT_POINT" || {
            log "错误: 无法卸载 $MOUNT_POINT"
            exit 1
        }
        log "✓ 已卸载旧的设备"
    fi
fi

log "====== 验证完成 ======"
exit 0
