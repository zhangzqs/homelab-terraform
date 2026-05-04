#!/bin/bash
set -euo pipefail

# ==========================================
# LXC 挂载点配置脚本（幂等性保证）
# ==========================================

CONTAINER_ID="${container_id}"
MOUNT_POINT_ID="${mount_point_id}"
HOST_PATH="${host_path}"
CONTAINER_PATH="${container_path}"
MOUNT_CONFIG="${mount_config_string}"
RESTART_CONTAINER="${restart_container}"
STOP_BEFORE_MOUNT="${stop_before_mount}"

echo "========================================"
echo "开始配置 LXC 挂载点"
echo "========================================"
echo "容器 ID: $CONTAINER_ID"
echo "挂载点 ID: $MOUNT_POINT_ID"
echo "宿主机路径: $HOST_PATH"
echo "容器路径: $CONTAINER_PATH"
echo "挂载配置: $MOUNT_CONFIG"
echo "========================================"

# ==========================================
# 1. 前置条件检查
# ==========================================

echo "[1/5] 检查前置条件..."

# 检查 pct 命令是否可用
if ! command -v pct &> /dev/null; then
    echo "错误: 找不到 pct 命令。请确保在 Proxmox VE 宿主机上执行此脚本。" >&2
    exit 1
fi

# 检查宿主机路径是否存在
if [ ! -d "$HOST_PATH" ]; then
    echo "错误: 宿主机路径不存在: $HOST_PATH" >&2
    echo "提示: 请先创建此目录或确保路径正确" >&2
    exit 1
fi

# 检查容器是否存在
if ! pct status "$CONTAINER_ID" &> /dev/null; then
    echo "错误: 容器 $CONTAINER_ID 不存在" >&2
    exit 1
fi

echo "✓ 前置条件检查通过"

# ==========================================
# 2. 获取当前挂载配置（幂等性检查）
# ==========================================

echo "[2/5] 检查当前挂载配置..."

# 获取当前的挂载点配置
CURRENT_CONFIG=$(pct config "$CONTAINER_ID" | grep "^$MOUNT_POINT_ID:" | sed "s/^$MOUNT_POINT_ID: //") || true

if [ -n "$CURRENT_CONFIG" ]; then
    echo "当前配置: $CURRENT_CONFIG"

    # 比较当前配置和期望配置
    if [ "$CURRENT_CONFIG" = "$MOUNT_CONFIG" ]; then
        echo "✓ 挂载配置已存在且相同，无需更新"
        echo "========================================"
        echo "配置完成（无变化）"
        echo "========================================"
        exit 0
    else
        echo "⚠ 挂载配置存在但不同，将进行更新"
        echo "期望配置: $MOUNT_CONFIG"
    fi
else
    echo "挂载点 $MOUNT_POINT_ID 不存在，将创建新挂载"
fi

# ==========================================
# 3. 停止容器（如果需要）
# ==========================================

echo "[3/5] 检查容器状态..."

CONTAINER_STATUS=$(pct status "$CONTAINER_ID" | awk '{print $2}')
echo "容器当前状态: $CONTAINER_STATUS"

if [ "$STOP_BEFORE_MOUNT" = "true" ]; then
    if [ "$CONTAINER_STATUS" = "running" ]; then
        echo "停止容器 $CONTAINER_ID..."
        pct stop "$CONTAINER_ID"
        echo "✓ 容器已停止"
    else
        echo "容器已经是停止状态"
    fi
fi

# ==========================================
# 4. 配置挂载点
# ==========================================

echo "[4/5] 配置挂载点..."

# 执行挂载配置
if pct set "$CONTAINER_ID" "-$MOUNT_POINT_ID" "$MOUNT_CONFIG"; then
    echo "✓ 挂载点配置成功"
else
    echo "错误: 挂载点配置失败" >&2
    exit 1
fi

# 验证配置是否生效
NEW_CONFIG=$(pct config "$CONTAINER_ID" | grep "^$MOUNT_POINT_ID:" | sed "s/^$MOUNT_POINT_ID: //") || true

if [ "$NEW_CONFIG" = "$MOUNT_CONFIG" ]; then
    echo "✓ 配置验证成功"
else
    echo "错误: 配置验证失败" >&2
    echo "期望: $MOUNT_CONFIG" >&2
    echo "实际: $NEW_CONFIG" >&2
    exit 1
fi

# ==========================================
# 5. 重启容器（如果需要）
# ==========================================

echo "[5/5] 处理容器重启..."

if [ "$RESTART_CONTAINER" = "true" ]; then
    # 检查容器是否正在运行
    CURRENT_STATUS=$(pct status "$CONTAINER_ID" | awk '{print $2}')

    if [ "$CURRENT_STATUS" = "running" ]; then
        echo "重启容器 $CONTAINER_ID 使挂载生效..."
        pct restart "$CONTAINER_ID"
        echo "✓ 容器已重启"
    else
        echo "启动容器 $CONTAINER_ID 使挂载生效..."
        pct start "$CONTAINER_ID"
        echo "✓ 容器已启动"
    fi

    # 等待容器完全启动
    sleep 2

    # 验证容器状态
    FINAL_STATUS=$(pct status "$CONTAINER_ID" | awk '{print $2}')
    if [ "$FINAL_STATUS" = "running" ]; then
        echo "✓ 容器运行正常"
    else
        echo "警告: 容器状态异常: $FINAL_STATUS" >&2
    fi
else
    echo "跳过容器重启（restart_container = false）"
    echo "提示: 挂载点需要重启容器后才能在容器内生效"
fi

# ==========================================
# 完成
# ==========================================

echo "========================================"
echo "挂载点配置完成"
echo "========================================"
echo "容器 ID: $CONTAINER_ID"
echo "挂载点 ID: $MOUNT_POINT_ID"
echo "配置内容: $MOUNT_CONFIG"
echo "========================================"

exit 0
