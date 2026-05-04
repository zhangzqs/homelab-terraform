#!/bin/bash
set -euo pipefail

# 参数
MOUNT_POINT="${mount_point}"
DISK_UUID="${disk_uuid}"
DISK_LABEL="${disk_label}"
FILESYSTEM_TYPE="${filesystem_type}"
MOUNT_OPTIONS="${mount_options}"
AUTOMOUNT_ENABLED="${automount_enabled}"
AUTOMOUNT_TIMEOUT="${automount_timeout}"
OWNER="${owner}"
GROUP="${group}"
PERMISSIONS="${permissions}"

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "====== 开始配置自动磁盘挂载 ======"
log "磁盘UUID: $DISK_UUID"
log "挂载点: $MOUNT_POINT"
log "文件系统: $FILESYSTEM_TYPE"

# 1. 检查并安装必要的工具
log "检查必要的工具..."
if ! command -v systemctl &> /dev/null; then
    log "错误: 系统不支持 systemd"
    exit 1
fi

# 检查文件系统工具
case "$FILESYSTEM_TYPE" in
    ntfs)
        if ! command -v mount.ntfs &> /dev/null && ! command -v mount.ntfs-3g &> /dev/null; then
            log "安装 ntfs-3g..."
            if command -v apt-get &> /dev/null; then
                apt-get update -qq && apt-get install -y ntfs-3g
            elif command -v yum &> /dev/null; then
                yum install -y ntfs-3g
            elif command -v dnf &> /dev/null; then
                dnf install -y ntfs-3g
            else
                log "错误: 无法自动安装 ntfs-3g，请手动安装"
                exit 1
            fi
        fi
        ;;
    exfat)
        if ! command -v mount.exfat &> /dev/null; then
            log "安装 exfat-fuse..."
            if command -v apt-get &> /dev/null; then
                apt-get update -qq && apt-get install -y exfat-fuse exfat-utils
            elif command -v yum &> /dev/null; then
                yum install -y exfat-utils fuse-exfat
            elif command -v dnf &> /dev/null; then
                dnf install -y exfat-utils fuse-exfat
            else
                log "错误: 无法自动安装 exfat-fuse，请手动安装"
                exit 1
            fi
        fi
        ;;
esac

# 2. 创建挂载点目录
log "创建挂载点目录: $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

# 2.1 检查用户和组是否存在
log "检查用户和组..."
if ! id "$OWNER" &> /dev/null; then
    log "警告: 用户 $OWNER 不存在，将跳过权限设置"
    SKIP_PERMISSIONS=true
else
    SKIP_PERMISSIONS=false
fi

if [ "$SKIP_PERMISSIONS" = "false" ] && ! getent group "$GROUP" &> /dev/null; then
    log "警告: 组 $GROUP 不存在，将跳过权限设置"
    SKIP_PERMISSIONS=true
fi

# 3. 生成 systemd 单元文件名（将路径中的 / 转换为 -，去掉首个 /）
SYSTEMD_MOUNT_NAME=$(systemd-escape --path "$MOUNT_POINT").mount
SYSTEMD_AUTOMOUNT_NAME=$(systemd-escape --path "$MOUNT_POINT").automount

log "Systemd mount 单元: $SYSTEMD_MOUNT_NAME"
log "Systemd automount 单元: $SYSTEMD_AUTOMOUNT_NAME"

# 4. 创建 systemd mount 单元文件
log "创建 systemd mount 单元文件..."
cat > "/etc/systemd/system/$SYSTEMD_MOUNT_NAME" <<EOF
[Unit]
Description=Mount $DISK_LABEL disk
Documentation=man:systemd.mount(5)

[Mount]
What=/dev/disk/by-uuid/$DISK_UUID
Where=$MOUNT_POINT
Type=$FILESYSTEM_TYPE
Options=$MOUNT_OPTIONS

[Install]
WantedBy=multi-user.target
EOF

# 5. 创建 systemd automount 单元文件（如果启用）
if [ "$AUTOMOUNT_ENABLED" = "true" ]; then
    log "创建 systemd automount 单元文件..."
    cat > "/etc/systemd/system/$SYSTEMD_AUTOMOUNT_NAME" <<EOF
[Unit]
Description=Automount $DISK_LABEL disk
Documentation=man:systemd.automount(5)

[Automount]
Where=$MOUNT_POINT
EOF

    if [ "$AUTOMOUNT_TIMEOUT" != "0" ]; then
        echo "TimeoutIdleSec=$AUTOMOUNT_TIMEOUT" >> "/etc/systemd/system/$SYSTEMD_AUTOMOUNT_NAME"
    fi

    cat >> "/etc/systemd/system/$SYSTEMD_AUTOMOUNT_NAME" <<EOF

[Install]
WantedBy=multi-user.target
EOF
fi

# 6. 重新加载 systemd
log "重新加载 systemd 配置..."
systemctl daemon-reload

# 7. 停止并禁用旧的服务（幂等性）
log "停止旧的服务..."
systemctl stop "$SYSTEMD_MOUNT_NAME" 2>/dev/null || true
systemctl stop "$SYSTEMD_AUTOMOUNT_NAME" 2>/dev/null || true
systemctl disable "$SYSTEMD_MOUNT_NAME" 2>/dev/null || true
systemctl disable "$SYSTEMD_AUTOMOUNT_NAME" 2>/dev/null || true

# 8. 启用并启动服务
if [ "$AUTOMOUNT_ENABLED" = "true" ]; then
    log "启用 automount 服务..."
    systemctl enable "$SYSTEMD_AUTOMOUNT_NAME"
    systemctl start "$SYSTEMD_AUTOMOUNT_NAME"
    log "Automount 服务已启动（按需挂载）"
else
    log "启用 mount 服务..."
    systemctl enable "$SYSTEMD_MOUNT_NAME"
    systemctl start "$SYSTEMD_MOUNT_NAME"
    log "Mount 服务已启动（立即挂载）"
fi

# 9. 等待挂载完成（如果是立即挂载）
if [ "$AUTOMOUNT_ENABLED" = "false" ]; then
    log "等待挂载完成..."
    sleep 2

    # 检查挂载状态
    if mountpoint -q "$MOUNT_POINT"; then
        log "磁盘挂载成功"

        # 设置权限
        if [ "$SKIP_PERMISSIONS" = "false" ]; then
            log "设置挂载点权限: $OWNER:$GROUP $PERMISSIONS"
            chown "$OWNER:$GROUP" "$MOUNT_POINT"
            chmod "$PERMISSIONS" "$MOUNT_POINT"
        else
            log "跳过权限设置"
        fi
    else
        log "警告: 磁盘未挂载，请检查磁盘是否已连接"
        log "提示: 使用 'lsblk' 或 'blkid' 命令检查磁盘UUID"
        log "提示: 使用 'journalctl -u $SYSTEMD_MOUNT_NAME' 查看详细错误"
    fi
else
    log "Automount 已配置，磁盘将在访问时自动挂载"

    # 在 automount 模式下，创建一个 systemd path unit 来监听首次挂载并设置权限
    if [ "$SKIP_PERMISSIONS" = "false" ]; then
        log "配置首次挂载后的权限设置..."
        SYSTEMD_PATH_NAME=$(systemd-escape --path "$MOUNT_POINT").path

        cat > "/etc/systemd/system/set-mount-permissions-$${DISK_LABEL}.service" <<EOF
[Unit]
Description=Set permissions for $DISK_LABEL mount point
After=$SYSTEMD_MOUNT_NAME

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'chown $OWNER:$GROUP $MOUNT_POINT && chmod $PERMISSIONS $MOUNT_POINT'
RemainAfterExit=yes
EOF

        systemctl daemon-reload
        systemctl enable "set-mount-permissions-$${DISK_LABEL}.service" || true
    fi
fi

# 10. 显示状态
log "====== 配置完成 ======"
log ""
log "服务状态:"
if [ "$AUTOMOUNT_ENABLED" = "true" ]; then
    systemctl status "$SYSTEMD_AUTOMOUNT_NAME" --no-pager || true
else
    systemctl status "$SYSTEMD_MOUNT_NAME" --no-pager || true
fi

log ""
log "挂载信息:"
df -h "$MOUNT_POINT" 2>/dev/null || log "磁盘尚未挂载（automount模式下正常）"

log ""
log "管理命令:"
if [ "$AUTOMOUNT_ENABLED" = "true" ]; then
    log "  查看状态: systemctl status $SYSTEMD_AUTOMOUNT_NAME"
    log "  停止服务: systemctl stop $SYSTEMD_AUTOMOUNT_NAME"
    log "  启动服务: systemctl start $SYSTEMD_AUTOMOUNT_NAME"
    log "  禁用服务: systemctl disable $SYSTEMD_AUTOMOUNT_NAME"
else
    log "  查看状态: systemctl status $SYSTEMD_MOUNT_NAME"
    log "  停止服务: systemctl stop $SYSTEMD_MOUNT_NAME"
    log "  启动服务: systemctl start $SYSTEMD_MOUNT_NAME"
    log "  禁用服务: systemctl disable $SYSTEMD_MOUNT_NAME"
fi

log "====== 完成 ======"
