#!/bin/bash
set -e

# 参数验证
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <private_key> <host_ip>" >&2
  exit 1
fi

PRIVATE_KEY="$1"
HOST_IP="$2"

# 创建临时 SSH 密钥文件
SSH_KEY_FILE=$(mktemp)
trap "rm -f $SSH_KEY_FILE" EXIT

echo "$PRIVATE_KEY" > $SSH_KEY_FILE
chmod 600 $SSH_KEY_FILE

# 通过 SSH 获取 kubeconfig
KUBECONFIG_CONTENT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i $SSH_KEY_FILE root@${HOST_IP} \
  "cat /etc/rancher/k3s/k3s.yaml" 2>/dev/null)

# 替换 IP 地址
KUBECONFIG_CONTENT=$(echo "$KUBECONFIG_CONTENT" | sed "s/127.0.0.1/${HOST_IP}/g")

# 使用 Python 输出 JSON
python3 -c "import json; print(json.dumps({'kubeconfig': '''$KUBECONFIG_CONTENT'''}))"
