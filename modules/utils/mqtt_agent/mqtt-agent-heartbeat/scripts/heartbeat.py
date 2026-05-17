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

from pathlib import Path

SHARED_DIR = Path(__file__).resolve().parents[2] / "shared"
if str(SHARED_DIR) not in sys.path:
    sys.path.insert(0, str(SHARED_DIR))

import mqtt_light as mqtt

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
    
    client = mqtt.Client(client_id="terraform-heartbeat-waiter")
    client.on_connect = on_connect
    client.on_message = on_message

    # Setup TLS
    client.tls_set()
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
