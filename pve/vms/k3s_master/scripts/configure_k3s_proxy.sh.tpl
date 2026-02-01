#!/bin/bash
set -e

%{ if has_proxy }
# 配置 containerd 代理
cat > /etc/systemd/system/k3s.service.env <<'EOF'
CONTAINERD_HTTP_PROXY=${http_proxy}
CONTAINERD_HTTPS_PROXY=${https_proxy}
CONTAINERD_NO_PROXY=${no_proxy}
EOF

echo "✓ K3s 代理配置已创建"
%{ else }
# 删除代理配置
rm -f /etc/systemd/system/k3s.service.env
echo "✓ K3s 代理配置已删除"
%{ endif }

# 重新加载 systemd 并重启 k3s
systemctl daemon-reload
systemctl restart k3s

# 等待 k3s 启动
sleep 5

# 检查 k3s 状态
systemctl status k3s --no-pager || true
