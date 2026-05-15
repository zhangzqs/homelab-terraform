#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

mkdir -p /opt/mqtt-agent
cat > /opt/mqtt-agent/mqtt_crypto.py <<'PY'
${shared_py}
PY
cat > /opt/mqtt-agent/agent.py <<'PY'
${agent_py}
PY
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
chmod 644 /opt/mqtt-agent/agent-cert.pem /opt/mqtt-agent/terraform-cert.pem /opt/mqtt-agent/mqtt_crypto.py /opt/mqtt-agent/agent.py

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

# Install paho-mqtt from PyPI wheel — no apt/pip install needed, pure stdlib
python3 -c "
import urllib.request, zipfile, json, site, sys
log = open('/var/log/mqtt-agent-setup.log', 'a')
def pr(msg):
    print(msg, flush=True, file=log)
try:
    pr('Fetching paho-mqtt metadata from PyPI...')
    with urllib.request.urlopen('https://pypi.org/pypi/paho-mqtt/json', timeout=120) as r:
        data = json.load(r)
    version = data['info']['version']
    pr(f'Latest paho-mqtt version: {version}')
    # Prefer a py3-any wheel
    files = data['releases'][version]
    wheel_url = next(
        (f['url'] for f in files if f['filename'].endswith('.whl') and 'py3' in f['filename']),
        next((f['url'] for f in files if f['filename'].endswith('.whl')), None)
    )
    if not wheel_url:
        raise RuntimeError('No wheel found for paho-mqtt')
    pr(f'Downloading {wheel_url}')
    urllib.request.urlretrieve(wheel_url, '/tmp/paho_mqtt.whl')
    dest = site.getsitepackages()[0]
    pr(f'Extracting wheel to {dest}')
    with zipfile.ZipFile('/tmp/paho_mqtt.whl') as z:
        z.extractall(dest)
    pr('paho-mqtt installed successfully')
except Exception as e:
    pr(f'ERROR installing paho-mqtt: {e}')
    sys.exit(1)
"

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
