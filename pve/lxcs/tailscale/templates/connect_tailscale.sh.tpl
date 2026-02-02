#!/bin/bash
set -e

# 先down再up以确保配置生效
tailscale down 2>/dev/null || true
sleep 2

# 使用authkey连接到Tailscale网络
tailscale up \
  --authkey=${auth_key} \
%{ if hostname != "" ~}
  --hostname=${hostname} \
%{ endif ~}
%{ if length(advertise_routes) > 0 ~}
  --advertise-routes=${join(",", advertise_routes)} \
%{ endif ~}
%{ if accept_routes ~}
  --accept-routes \
%{ endif ~}
%{ if exit_node ~}
  --advertise-exit-node \
%{ endif ~}
%{ if ssh_enabled ~}
  --ssh \
%{ endif ~}
  --accept-dns=false

# 等待连接建立
sleep 3

# 显示状态
tailscale status
tailscale ip -4

# 如果启用了子网路由，显示路由信息
%{ if length(advertise_routes) > 0 ~}
echo "Subnet routes advertised: ${join(",", advertise_routes)}"
%{ else ~}
echo "No subnet routes configured"
%{ endif ~}

# 如果启用了metrics，显示metrics端点
%{ if metrics_enabled ~}
echo "Prometheus metrics available at: http://${ipv4_address}:${metrics_port}/metrics"
%{ else ~}
echo "Metrics disabled"
%{ endif ~}
