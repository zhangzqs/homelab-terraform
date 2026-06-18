#!/bin/sh
# 在 PVE 宿主机上下载并解压 HAOS qcow2 镜像。
# bpg/proxmox 0.93 的 download_file 不支持 xz 解压，HAOS 官方
# 发布只提供 .qcow2.xz，所以走这个脚本在宿主机侧下载。
set -euo pipefail

%{ if download_proxy_enabled ~}
export http_proxy='${http_proxy}'
export https_proxy='${https_proxy}'
%{ endif ~}

TARGET_DIR=/var/lib/vz/import
mkdir -p "$TARGET_DIR"
TARGET_FILE="$TARGET_DIR/haos_ova-${haos_version}.qcow2"

if [ ! -f "$TARGET_FILE" ]; then
  TMP_XZ="$TARGET_DIR/haos_ova-${haos_version}.qcow2.xz"
  rm -f "$TMP_XZ"
  wget --tries=3 --timeout=60 -O "$TMP_XZ" \
    'https://github.com/home-assistant/operating-system/releases/download/${haos_version}/haos_ova-${haos_version}.qcow2.xz'
  unxz "$TMP_XZ"
fi

ls -lh "$TARGET_FILE"
