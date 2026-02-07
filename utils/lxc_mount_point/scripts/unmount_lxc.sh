#!/bin/bash
set -euo pipefail

# ==========================================
# LXC 挂载点卸载脚本
# ==========================================

CONTAINER_ID="${container_id}"
MOUNT_POINT_ID="${mount_point_id}"
RESTART_CONTAINER="${restart_container}"

echo "========================================"
echo "开始卸载 LXC 挂载点"
echo "========================================"
echo "容器 ID: $CONTAINER_ID"
echo "挂载点 ID: $MOUNT_POINT_ID"
echo "========================================"

# ==========================================
# 1. 检查容器和挂载点
# ==========================================

echo "[1/3] 检查容器和挂载点..."

# 检查 pct 命令是否可用
if ! command -v pct &> /dev/null; then
    echo "警告: 找不到 pct 命令，跳过卸载" >&2
    exit 0
fi

# 检查容器是否存在
if ! pct status "$CONTAINER_ID" &> /dev/null; then
    echo "警告: 容器 $CONTAINER_ID 不存在，跳过卸载" >&2
    exit 0
fi

# 检查挂载点是否存在
CURRENT_CONFIG=$(pct config "$CONTAINER_ID" | grep "^$MOUNT_POINT_ID:" | sed "s/^$MOUNT_POINT_ID: //") || true

if [ -z "$CURRENT_CONFIG" ]; then
    echo "挂载点 $MOUNT_POINT_ID 不存在，无需卸载"
    echo "========================================"
    echo "卸载完成（无变化）"
    echo "========================================"
    exit 0
fi

echo "找到挂载配置: $CURRENT_CONFIG"
echo "✓ 检查完成"

# ==========================================
# 2. 删除挂载点配置
# ==========================================

echo "[2/3] 删除挂载点配置..."

# 删除挂载点
if pct set "$CONTAINER_ID" --delete "$MOUNT_POINT_ID"; then
    echo "✓ 挂载点已删除"
else
    echo "警告: 删除挂载点失败，可能已经被删除" >&2
fi

# 验证删除是否成功
VERIFY_CONFIG=$(pct config "$CONTAINER_ID" | grep "^$MOUNT_POINT_ID:" | sed "s/^$MOUNT_POINT_ID: //") || true

if [ -z "$VERIFY_CONFIG" ]; then
    echo "✓ 挂载点删除验证成功"
else
    echo "警告: 挂载点可能仍然存在: $VERIFY_CONFIG" >&2
fi

# ==========================================
# 3. 重启容器（如果需要）
# ==========================================

echo "[3/3] 处理容器重启..."

if [ "$RESTART_CONTAINER" = "true" ]; then
    # 检查容器是否正在运行
    CONTAINER_STATUS=$(pct status "$CONTAINER_ID" | awk '{print $2}')

    if [ "$CONTAINER_STATUS" = "running" ]; then
        echo "重启容器 $CONTAINER_ID 使更改生效..."
        pct restart "$CONTAINER_ID"
        echo "✓ 容器已重启"

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
        echo "容器未运行，跳过重启"
    fi
else
    echo "跳过容器重启（restart_container = false）"
fi

# ==========================================
# 完成
# ==========================================

echo "========================================"
echo "挂载点卸载完成"
echo "========================================"
echo "容器 ID: $CONTAINER_ID"
echo "挂载点 ID: $MOUNT_POINT_ID"
echo "========================================"

exit 0
