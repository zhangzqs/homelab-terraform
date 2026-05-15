#!/usr/bin/env python3
"""
Wait for MQTT Agent heartbeat to confirm agent readiness.

Reads JSON from stdin with:
- broker_host, broker_port, topic_prefix
- instance_id (node_id)
- terraform_private_key_pem, terraform_certificate_pem
- agent_certificate_pem
- timeout, poll_interval

Waits for heartbeat message on {topic_prefix}/{instance_id}/heartbeat,
verifies signature/encryption, and returns {"received": "true"} when first heartbeat arrives.
"""

import json
import sys
import time
import traceback
import ssl
import subprocess
import venv
import os
import tempfile
from pathlib import Path

# Setup shared module path - go up from scripts to heartbeat module, then up to modules, then to shared
shared_path = str(Path(__file__).parent.parent.parent / 'shared')
if shared_path not in sys.path:
    sys.path.insert(0, shared_path)

# Download/import paho-mqtt
try:
    import paho.mqtt.client as mqtt
except ImportError:
    print("paho-mqtt not found, creating venv...", file=sys.stderr)
    sys.stderr.flush()
    
    venv_dir = Path(os.getenv("MQTT_HEARTBEAT_VENV", Path.home() / ".cache" / "mqtt-heartbeat-venv"))
    python_bin = venv_dir / "bin" / "python"
    
    if not python_bin.exists():
        builder = venv.EnvBuilder(with_pip=True)
        builder.create(venv_dir)
    
    subprocess.run([str(python_bin), "-m", "pip", "install", "--upgrade", "--quiet", "paho-mqtt"], 
                   check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    
    site_packages = next((venv_dir / "lib").glob("python*/site-packages"))
    sys.path.insert(0, str(site_packages))
    
    # Re-ensure shared path is at front (go up from scripts to heartbeat module, then up to modules, then to shared)
    shared_path_fixed = str(Path(__file__).parent.parent.parent / 'shared')
    if shared_path_fixed in sys.path:
        sys.path.remove(shared_path_fixed)
    sys.path.insert(0, shared_path_fixed)
    
    import paho.mqtt.client as mqtt

from mqtt_crypto import unpack_message

def main():
    data = json.loads(sys.stdin.read())
    
    broker_host = data["broker_host"]
    broker_port = int(data["broker_port"])
    topic_prefix = data["topic_prefix"]
    instance_id = data["instance_id"]
    timeout = int(data["timeout"])
    poll_interval = float(data["poll_interval"])
    
    terraform_private_key_pem = data["terraform_private_key_pem"]
    terraform_certificate_pem = data["terraform_certificate_pem"]
    agent_certificate_pem = data["agent_certificate_pem"]
    
    heartbeat_topic = f"{topic_prefix}/{instance_id}/heartbeat"
    
    heartbeat_received = {"flag": False, "message": None}
    
    def on_connect(client, userdata, flags, rc):
        if rc != 0:
            print(f"Connection failed with code {rc}", file=sys.stderr)
            return
        client.subscribe(heartbeat_topic)
    
    def on_message(client, userdata, msg):
        try:
            payload = msg.payload.decode('utf-8')
            message = unpack_message(
                payload,
                recipient_cert_pem=terraform_certificate_pem,
                recipient_key_pem=terraform_private_key_pem,
                expected_signer_cert_pem=agent_certificate_pem
            )
            
            if message and message.get("message_type") == "heartbeat":
                heartbeat_received["flag"] = True
                heartbeat_received["message"] = message
                client.disconnect()
        except Exception as e:
            print(f"Error processing heartbeat: {e}", file=sys.stderr)
            traceback.print_exc(file=sys.stderr)
    
    client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1, client_id="terraform-heartbeat-waiter")
    client.on_connect = on_connect
    client.on_message = on_message
    
    # Write PEM content to temporary files
    tmpdir = tempfile.mkdtemp()
    
    cert_file = Path(tmpdir) / "terraform.crt"
    cert_file.write_text(terraform_certificate_pem)
    
    key_file = Path(tmpdir) / "terraform.key"
    key_file.write_text(terraform_private_key_pem)
    
    # Setup TLS
    client.tls_set(ca_certs=None, certfile=str(cert_file), keyfile=str(key_file),
                   cert_reqs=ssl.CERT_NONE, tls_version=ssl.PROTOCOL_TLSv1_2, ciphers=None)
    client.tls_insecure_set(True)
    
    try:
        client.connect(broker_host, broker_port, keepalive=60)
        client.loop_start()
        
        start_time = time.time()
        while not heartbeat_received["flag"]:
            elapsed = time.time() - start_time
            if elapsed > timeout:
                raise TimeoutError(f"Heartbeat not received within {timeout}s")
            
            time.sleep(poll_interval)
        
        client.loop_stop()
        
        # Return success
        print(json.dumps({"received": "true", "status": "heartbeat confirmed"}))
        return 0
    
    except Exception as e:
        print(json.dumps({
            "error": str(e),
            "status": "heartbeat wait failed"
        }))
        return 1

if __name__ == "__main__":
    sys.exit(main())
