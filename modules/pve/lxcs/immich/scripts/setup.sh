#!/usr/bin/env bash

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y ca-certificates cron curl gnupg rsync

install -m 0755 -d /etc/apt/keyrings
if [ -n "${DOCKER_SETUP_HTTP_PROXY:-}" ]; then
  export http_proxy="${DOCKER_SETUP_HTTP_PROXY}"
  export https_proxy="${DOCKER_SETUP_HTTPS_PROXY:-$DOCKER_SETUP_HTTP_PROXY}"
  export HTTP_PROXY="${DOCKER_SETUP_HTTP_PROXY}"
  export HTTPS_PROXY="${DOCKER_SETUP_HTTPS_PROXY:-$DOCKER_SETUP_HTTP_PROXY}"
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor --batch --yes -o /etc/apt/keyrings/docker.gpg
test -s /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
if [ -n "${DOCKER_SETUP_HTTP_PROXY:-}" ]; then
  cat > /etc/apt/apt.conf.d/99docker-proxy <<EOF
Acquire::http::Proxy::download.docker.com "${DOCKER_SETUP_HTTP_PROXY}";
Acquire::https::Proxy::download.docker.com "${DOCKER_SETUP_HTTPS_PROXY:-$DOCKER_SETUP_HTTP_PROXY}";
EOF
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
fi

. /etc/os-release
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
  >/etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable cron
systemctl restart cron
systemctl enable docker
systemctl restart docker
