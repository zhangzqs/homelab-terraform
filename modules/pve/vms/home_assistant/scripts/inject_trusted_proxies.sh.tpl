#!/bin/sh
# 通过 qm guest exec 给 HAOS 的 configuration.yaml 注入
# `http.use_x_forwarded_for + http.trusted_proxies` 段。
#
# 幂等设计：
# - 文件不存在时（onboarding 未完成，HA core 未初始化配置目录）静默退出 0，
#   用户完成 onboarding 后再次 apply 才生效。
# - 文件存在时：用 BEGIN/END 标记块判断
#     * 标记块已存在且内容一致 -> 不动
#     * 标记块已存在但内容不同 -> 替换
#     * 标记块不存在 -> 追加到文件末尾（HA 默认 configuration.yaml 不含 http:，
#       直接追加是 100% 安全的；如果用户手工加过 http:，会因 YAML 同 key 报错，
#       届时用户需手动合并 —— 这种情况下 apply 输出会有提示）
# - 改动后调用 `ha core restart` 让 HA 重新加载配置。
set -euo pipefail

VMID='${vm_id}'
CONFIG_PATH='${config_path}'
MARKER_BEGIN='${marker_begin}'
MARKER_END='${marker_end}'

# 模板渲染好的完整 yaml 块（包含 BEGIN/END 标记注释）
EXPECTED_BLOCK=$(cat <<'YAMLEOF'
${yaml_block}
YAMLEOF
)

EXPECTED_BLOCK_B64=$(printf '%s' "$EXPECTED_BLOCK" | base64 -w0)

# guest 内执行的逻辑：检查 + 替换/追加
GUEST_SCRIPT=$(cat <<'GSCRIPT'
set -eu
CONFIG="__CONFIG__"
BEGIN="__BEGIN__"
END="__END__"
EXPECTED=$(echo '__EXPECTED_B64__' | base64 -d)

if [ ! -f "$CONFIG" ]; then
  echo "[skip] $CONFIG not yet exists; complete HA onboarding then re-apply."
  exit 0
fi

if grep -qF "$BEGIN" "$CONFIG"; then
  # 提取现有标记块
  current=$(awk -v b="$BEGIN" -v e="$END" '
    $0 ~ b { in_block = 1 }
    in_block { print }
    $0 ~ e { in_block = 0 }
  ' "$CONFIG")
  if [ "$current" = "$EXPECTED" ]; then
    echo "[ok] trusted_proxies block already up-to-date"
    exit 0
  fi
  # 替换
  awk -v b="$BEGIN" -v e="$END" -v block="$EXPECTED" '
    BEGIN { skip = 0 }
    $0 ~ b { print block; skip = 1; next }
    skip && $0 ~ e { skip = 0; next }
    !skip { print }
  ' "$CONFIG" > "$CONFIG.tf-new"
  mv "$CONFIG.tf-new" "$CONFIG"
  echo "[+] replaced trusted_proxies block"
  echo "RESTART_NEEDED" > /tmp/.ha-tf-restart
else
  if grep -qE '^http:' "$CONFIG"; then
    echo "[warn] $CONFIG already has top-level 'http:' but no Terraform marker."
    echo "[warn] Manually merge: use_x_forwarded_for: true + trusted_proxies."
    exit 0
  fi
  printf '\n%s\n' "$EXPECTED" >> "$CONFIG"
  echo "[+] appended trusted_proxies block"
  echo "RESTART_NEEDED" > /tmp/.ha-tf-restart
fi
GSCRIPT
)

# 把占位符塞回去（避免 heredoc 内层取值时被 host shell 扩展）
GUEST_SCRIPT=$(printf '%s' "$GUEST_SCRIPT" \
  | sed -e "s|__CONFIG__|$CONFIG_PATH|g" \
        -e "s|__BEGIN__|$MARKER_BEGIN|g" \
        -e "s|__END__|$MARKER_END|g" \
        -e "s|__EXPECTED_B64__|$EXPECTED_BLOCK_B64|g")

GUEST_SCRIPT_B64=$(printf '%s' "$GUEST_SCRIPT" | base64 -w0)

echo "[+] applying trusted_proxies on VM $VMID"
qm guest exec "$VMID" -- /bin/sh -c \
  "echo '$GUEST_SCRIPT_B64' | base64 -d | sh"

# 仅在确实变更时重启 HA
echo "[+] checking if HA restart needed"
restart_check=$(qm guest exec "$VMID" -- /bin/sh -c \
  "[ -f /tmp/.ha-tf-restart ] && rm -f /tmp/.ha-tf-restart && echo YES || echo NO")
if echo "$restart_check" | grep -q '"YES"'; then
  echo "[+] restarting Home Assistant core"
  qm guest exec "$VMID" --timeout 120 -- /bin/sh -c \
    "ha core restart 2>&1 || docker restart homeassistant 2>&1" || true
  echo "[+] HA restart triggered"
else
  echo "[ok] no restart needed"
fi
