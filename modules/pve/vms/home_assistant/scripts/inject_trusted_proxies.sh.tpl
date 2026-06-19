#!/bin/sh
# 通过 qm guest exec 给 HAOS 的 configuration.yaml 注入
# `http.use_x_forwarded_for + http.trusted_proxies` 段。
#
# 幂等设计：
# - 文件不存在时（onboarding 未完成，HA core 未初始化配置目录）静默退出 0，
#   用户完成 onboarding 后再次 apply 才生效。
# - 文件存在时：用 BEGIN/END 标记块判断
#     * 标记块已存在且内容一致 -> 不动
#     * 标记块已存在但内容不同 -> 替换 + 重启 HA
#     * 标记块不存在 -> 追加到文件末尾 + 重启 HA
#       （HA 默认 configuration.yaml 不含 http:，直接追加是 100% 安全的；
#        如果用户手工加过 http:，会因 YAML 同 key 报错，届时脚本会输出
#        警告让用户手工合并）
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

# guest 内执行的逻辑：检查 + 替换/追加 + （需要时）重启 HA
# 把检查和重启放到同一次 guest exec，避免跨 exec 共享 /tmp 文件。
# 通过 stdout 第一行返回状态：CHANGED / UNCHANGED / WARN
GUEST_SCRIPT=$(cat <<'GSCRIPT'
set -eu
CONFIG="__CONFIG__"
BEGIN="__BEGIN__"
END="__END__"
EXPECTED=$(echo '__EXPECTED_B64__' | base64 -d)

if [ ! -f "$CONFIG" ]; then
  echo "SKIP_NO_FILE"
  echo "[skip] $CONFIG not yet exists; complete HA onboarding then re-apply." >&2
  exit 0
fi

CHANGED=0
if grep -qF "$BEGIN" "$CONFIG"; then
  # 提取现有标记块
  current=$(awk -v b="$BEGIN" -v e="$END" '
    $0 ~ b { in_block = 1 }
    in_block { print }
    $0 ~ e { in_block = 0 }
  ' "$CONFIG")
  if [ "$current" = "$EXPECTED" ]; then
    echo "UNCHANGED"
    echo "[ok] trusted_proxies block already up-to-date" >&2
    exit 0
  fi
  awk -v b="$BEGIN" -v e="$END" -v block="$EXPECTED" '
    BEGIN { skip = 0 }
    $0 ~ b { print block; skip = 1; next }
    skip && $0 ~ e { skip = 0; next }
    !skip { print }
  ' "$CONFIG" > "$CONFIG.tf-new"
  mv "$CONFIG.tf-new" "$CONFIG"
  echo "[+] replaced trusted_proxies block" >&2
  CHANGED=1
else
  if grep -qE '^http:' "$CONFIG"; then
    echo "WARN_HTTP_EXISTS"
    echo "[warn] $CONFIG already has top-level 'http:' but no Terraform marker." >&2
    echo "[warn] Manually merge: use_x_forwarded_for: true + trusted_proxies." >&2
    exit 0
  fi
  printf '\n%s\n' "$EXPECTED" >> "$CONFIG"
  echo "[+] appended trusted_proxies block" >&2
  CHANGED=1
fi

if [ "$CHANGED" = "1" ]; then
  echo "CHANGED"
  echo "[+] restarting Home Assistant core to apply" >&2
  # `ha core restart` 同步等待 HA 起来（可能耗时），用后台 + nohup 防 guest agent 超时
  # 实测 ha core restart 是 fire-and-forget，不会等 HA 完全就绪才返回
  ha core restart >/dev/null 2>&1 || docker restart homeassistant >/dev/null 2>&1 || true
  echo "[+] HA restart triggered" >&2
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
qm guest exec "$VMID" --timeout 120 -- /bin/sh -c \
  "echo '$GUEST_SCRIPT_B64' | base64 -d | sh"
