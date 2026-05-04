#!/bin/bash
set -e

AUTHORIZED_KEYS_FILE="/root/.ssh/authorized_keys"
BACKUP_FILE="/root/.ssh/authorized_keys.backup"

echo "==> 管理 SSH 公钥"

# 确保 .ssh 目录存在
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 备份现有的 authorized_keys
if [ -f "$AUTHORIZED_KEYS_FILE" ]; then
  cp "$AUTHORIZED_KEYS_FILE" "$BACKUP_FILE"
  echo "✓ 已备份现有公钥到 $BACKUP_FILE"
fi

# 创建临时文件存储新的公钥列表
TEMP_KEYS=$(mktemp)
trap "rm -f $TEMP_KEYS" EXIT

# 保留 Terraform 自动生成的密钥 (如果存在)
%{ if terraform_key != "" }
echo "${terraform_key}" >> "$TEMP_KEYS"
echo "✓ 保留 Terraform 自动生成的密钥"
%{ endif }

# 添加额外的公钥
%{ if length(additional_keys) > 0 }
%{ for key in additional_keys }
echo "${key}" >> "$TEMP_KEYS"
%{ endfor }
echo "✓ 添加了 ${length(additional_keys)} 个额外的公钥"
%{ else }
echo "ℹ 没有额外的公钥需要添加"
%{ endif }

# 去重并写入 authorized_keys
if [ -s "$TEMP_KEYS" ]; then
  sort -u "$TEMP_KEYS" > "$AUTHORIZED_KEYS_FILE"
  chmod 600 "$AUTHORIZED_KEYS_FILE"
  echo "✓ SSH 公钥配置已更新"

  # 显示当前公钥数量
  KEY_COUNT=$(wc -l < "$AUTHORIZED_KEYS_FILE")
  echo "✓ 当前共有 $KEY_COUNT 个授权的公钥"
else
  echo "⚠ 警告: 没有任何公钥，保留原有配置"
  if [ -f "$BACKUP_FILE" ]; then
    cp "$BACKUP_FILE" "$AUTHORIZED_KEYS_FILE"
  fi
fi

# 重启 SSH 服务以确保配置生效
systemctl reload sshd || systemctl reload ssh || true
echo "✓ SSH 服务已重新加载"
