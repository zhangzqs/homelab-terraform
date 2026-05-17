#!/usr/bin/env python3
"""MQTT command executor."""

from __future__ import annotations

import datetime as dt
import json
import os
import sys
import threading
import time
from pathlib import Path
from typing import Any

SHARED_DIR = Path(__file__).resolve().parents[2] / "shared"
if str(SHARED_DIR) not in sys.path:
    sys.path.insert(0, str(SHARED_DIR))

import mqtt_light as mqtt
from mqtt_crypto import pack_message, unpack_message


def _read_query() -> dict[str, Any]:
    raw = sys.stdin.read()
    if not raw.strip():
        raise RuntimeError("missing query")
    return json.loads(raw)


def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def main() -> int:
    query = _read_query()
    broker_host = query["broker_host"]
    broker_port = int(query["broker_port"])
    topic_prefix = query["topic_prefix"]
    instance_id = query["instance_id"]
    task_uuid = query["task_uuid"]
    command_type = query["command_type"]
    command = query["command"]
    timeout = int(query["timeout"])
    poll_interval = float(query["poll_interval"])
    terraform_private_key_pem = query["terraform_private_key_pem"]
    terraform_certificate_pem = query["terraform_certificate_pem"]
    agent_certificate_pem = query["agent_certificate_pem"]

    command_topic = f"{topic_prefix}/{instance_id}/command"
    result_topic = f"{topic_prefix}/{instance_id}/result"
    nonce = os.urandom(16).hex()
    sent_at = _iso(_now_utc())
    command_payload = {
        "message_type": "command",
        "task_uuid": task_uuid,
        "nonce": nonce,
        "sent_at": sent_at,
        "command_type": command_type,
        "command": command,
    }

    package_b64 = pack_message(
        command_payload,
        signer_cert_pem=terraform_certificate_pem,
        signer_key_pem=terraform_private_key_pem,
        recipient_cert_pem=agent_certificate_pem,
    )

    client = mqtt.Client(client_id=f"mqtt-exec-{task_uuid}", clean_session=True)
    client.tls_set()

    result_event = threading.Event()
    result_holder: dict[str, Any] = {}
    retained_checked_event = threading.Event()
    lock = threading.Lock()
    connected_event = threading.Event()
    stale_retained_cleared = threading.Event()

    def on_connect(client_obj: mqtt.Client, userdata: Any, flags: dict[str, Any], rc: int) -> None:
        client_obj.subscribe(result_topic, qos=1)
        connected_event.set()

    def on_message(client_obj: mqtt.Client, userdata: Any, message: mqtt.MQTTMessage) -> None:
        package = message.payload.decode("utf-8")
        if not package.strip():
            return  # empty payload = clear sentinel
        try:
            payload = unpack_message(
                package,
                recipient_cert_pem=terraform_certificate_pem,
                recipient_key_pem=terraform_private_key_pem,
                expected_signer_cert_pem=agent_certificate_pem,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"ignore invalid result: {exc}", file=sys.stderr)
            retained_checked_event.set()
            return

        if payload.get("message_type") != "result":
            retained_checked_event.set()
            return
        if payload.get("task_uuid") != task_uuid:
            # Stale retained result from a previous task; clear it.
            print(f"stale retained result for task {payload.get('task_uuid')}, clearing", file=sys.stderr)
            client_obj.publish(result_topic, b"", qos=1, retain=True)
            retained_checked_event.set()
            return
        with lock:
            result_holder.update(payload)
        retained_checked_event.set()
        result_event.set()

    client.on_connect = on_connect
    client.on_message = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=max(int(poll_interval), 5))
    client.connect(broker_host, broker_port, keepalive=60)
    client.loop_start()

    try:
        deadline = time.monotonic() + timeout
        if not connected_event.wait(timeout=min(30, timeout)):
            raise TimeoutError("mqtt connect timeout")

        # Wait briefly for any retained result from a previous run (idempotent re-run).
        retained_checked_event.wait(timeout=5)

        if not result_event.is_set():
            # No matching retained result; publish command with retain=True so the agent
            # receives it even if it connects after we publish.
            client.publish(command_topic, package_b64, qos=1, retain=True)
            while time.monotonic() < deadline:
                if result_event.wait(timeout=poll_interval):
                    break

        if not result_holder:
            raise TimeoutError(f"timeout after {timeout}s")

        # Clear the retained result so stale data doesn't affect future runs with different tasks.
        client.publish(result_topic, b"", qos=1, retain=True)

        print(
            json.dumps(
                {
                    "task_uuid": result_holder["task_uuid"],
                    "exit_code": str(result_holder["exit_code"]),
                    "output": result_holder.get("output", ""),
                    "executed_at": result_holder.get("executed_at", ""),
                },
                ensure_ascii=False,
            )
        )
        return 0 if int(result_holder["exit_code"]) == 0 else int(result_holder["exit_code"])
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
