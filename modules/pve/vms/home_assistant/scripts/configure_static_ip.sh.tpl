#!/bin/sh
# 通过 qm guest exec 给 HAOS 注入静态 IP。
# HAOS 出厂自带一个 `Supervisor <iface>` NetworkManager 连接（DHCP），
# 用 `nmcli con modify` 把它改成 manual + 我们的 IP，再重新激活。
# 比往 LABEL=CONFIG 卷拷文件更可靠：hassos-config 拷贝完成后，
# HA Supervisor 仍可能经 DBus 重置回 DHCP，覆盖我们的连接；
# 这里直接改活跃连接，立即生效，无需重启。
set -euo pipefail

VMID='${vm_id}'
IFACE='${interface_name}'
CONN_NAME="Supervisor $IFACE"

# 等 guest agent 至多 5 分钟
echo "[+] waiting qemu-guest-agent on VM $VMID"
for i in $(seq 1 60); do
  if qm guest cmd "$VMID" ping >/dev/null 2>&1; then
    echo "    agent up after $((i * 5))s"
    break
  fi
  sleep 5
done
qm guest cmd "$VMID" ping >/dev/null 2>&1 || {
  echo 'guest agent not responding' >&2
  exit 1
}

# 等 NetworkManager 起来并加载出厂 Supervisor 连接
# （由 HA Supervisor 容器经 DBus 反推下来）
echo "[+] waiting NetworkManager Supervisor connection"
for i in $(seq 1 60); do
  out=$(qm guest exec "$VMID" -- /bin/sh -c \
    "nmcli -t -f NAME con show | grep -qx 'Supervisor $IFACE'" 2>/dev/null || true)
  if echo "$out" | grep -q '"exitcode" : 0'; then
    echo "    Supervisor conn ready after $((i * 5))s"
    break
  fi
  sleep 5
done

# 改 IP + 重新激活；nmcli 设置 manual 时必须同时给 addresses
echo "[+] applying static IP via nmcli"
qm guest exec "$VMID" -- /bin/sh -c \
  "nmcli con modify '$CONN_NAME' \
     ipv4.method manual \
     ipv4.addresses '${ipv4_address}/${ipv4_cidr}' \
     ipv4.gateway '${ipv4_gateway}' \
     ipv4.dns '${ipv4_dns_csv}' \
   && nmcli con reload \
   && nmcli con up '$CONN_NAME'"
echo "[+] done"
