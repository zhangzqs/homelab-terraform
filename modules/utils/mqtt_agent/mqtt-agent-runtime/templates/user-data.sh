#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# 展开MQTT Agent压缩包内容
mkdir -p /opt/mqtt-agent
cat > /opt/mqtt-agent/runtime-payload.zip.b64 <<'B64'
${runtime_payload_tar_b64}
B64
base64 -d /opt/mqtt-agent/runtime-payload.zip.b64 > /opt/mqtt-agent/runtime-payload.zip
python3 - <<'PY'
import zipfile

z = zipfile.ZipFile('/opt/mqtt-agent/runtime-payload.zip')
z.extractall('/opt/mqtt-agent')
z.close()
PY
rm -f /opt/mqtt-agent/runtime-payload.zip.b64 /opt/mqtt-agent/runtime-payload.zip


# 展开端到端加密相关的证书和密钥，并设置权限
cat > /opt/mqtt-agent/agent-cert.pem <<'PEM'
${agent_certificate_pem}
PEM
cat > /opt/mqtt-agent/agent-key.pem <<'PEM'
${agent_private_key_pem}
PEM
cat > /opt/mqtt-agent/terraform-cert.pem <<'PEM'
${terraform_certificate_pem}
PEM
chmod 600 /opt/mqtt-agent/agent-key.pem
chmod 644 /opt/mqtt-agent/agent-cert.pem /opt/mqtt-agent/terraform-cert.pem /opt/mqtt-agent/mqtt_crypto.py /opt/mqtt-agent/mqtt_light.py /opt/mqtt-agent/agent.py

# 运行 MQTT Agent 服务
cat > /etc/mqtt-agent.env <<'ENV_EOF'
MQTT_BROKER_HOST=${broker_host}
MQTT_BROKER_PORT=${broker_port}
MQTT_TOPIC_PREFIX=${topic_prefix}
MQTT_INSTANCE_ID=${instance_id}
MQTT_POLL_INTERVAL=${poll_interval}
MQTT_REPLAY_WINDOW_SECONDS=${replay_window_seconds}
MQTT_LEDGER_PATH=${ledger_path}
MQTT_MAX_WORKERS=${max_workers}
MQTT_PYTHON=${python_executable}
ENV_EOF
chmod 600 /etc/mqtt-agent.env

cat > /etc/systemd/system/mqtt-agent.service <<'SERVICE_EOF'
[Unit]
Description=MQTT Command Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
EnvironmentFile=/etc/mqtt-agent.env
Environment=PATH=/usr/local/bin:/usr/bin:/bin:/root/.local/bin
ExecStart=${python_executable} /opt/mqtt-agent/agent.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl daemon-reload
systemctl enable mqtt-agent
systemctl start mqtt-agent
