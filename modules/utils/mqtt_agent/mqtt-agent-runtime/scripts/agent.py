#!/usr/bin/env python3
"""MQTT command agent."""

from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any

SHARED_DIR = Path("/opt/mqtt-agent")
if str(SHARED_DIR) not in sys.path:
    sys.path.insert(0, str(SHARED_DIR))

import mqtt_light as mqtt

from mqtt_crypto import pack_message, unpack_message


def _env(name: str, default: str | None = None) -> str:
    value = os.getenv(name, default)
    if value is None:
        raise RuntimeError(f"Missing environment variable: {name}")
    return value


def _now_utc() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(dt_value: dt.datetime) -> str:
    return dt_value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def _parse_iso(value: str) -> dt.datetime:
    return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))


def _ledger_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def _load_ledger(path: Path) -> tuple[set[str], dict[str, dict[str, Any]]]:
    completed: set[str] = set()
    metadata: dict[str, dict[str, Any]] = {}
    if not path.exists():
        return completed, metadata
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        item = json.loads(line)
        task_uuid = item["task_uuid"]
        metadata[task_uuid] = item
        if item.get("state") in {"success", "failure"}:
            completed.add(task_uuid)
    return completed, metadata


def _append_ledger(path: Path, item: dict[str, Any]) -> None:
    _ledger_parent(path)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(item, ensure_ascii=False, sort_keys=True) + "\n")


def _run_shell(command: str) -> tuple[int, str]:
    proc = subprocess.run(
        command,
        shell=True,
        executable="/bin/bash",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    return proc.returncode, proc.stdout or ""


def _run_shell_script(command: str) -> tuple[int, str]:
    with tempfile.NamedTemporaryFile("w", delete=False, suffix=".sh", encoding="utf-8") as handle:
        handle.write(command)
        script_path = handle.name
    try:
        proc = subprocess.run(
            ["/bin/bash", script_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        return proc.returncode, proc.stdout or ""
    finally:
        try:
            os.unlink(script_path)
        except FileNotFoundError:
            pass


def _run_command(command_type: str, command: str) -> tuple[int, str]:
    if command_type == "shell":
        return _run_shell(command)
    if command_type == "shell-script":
        return _run_shell_script(command)
    return 1, f"Unknown command type: {command_type}\n"


def _get_system_info() -> dict[str, Any]:
    """Gather system information for heartbeat."""
    try:
        import socket
        hostname = socket.gethostname()
    except Exception:
        hostname = "unknown"

    try:
        with open("/proc/uptime") as f:
            uptime_seconds = int(float(f.read().split()[0]))
    except Exception:
        uptime_seconds = 0

    return {
        "hostname": hostname,
        "uptime": uptime_seconds,
        "agent_version": "1.0",
        "status": "ready",
    }


def main() -> int:
    broker_host = _env("MQTT_BROKER_HOST")
    broker_port = int(_env("MQTT_BROKER_PORT"))
    topic_prefix = _env("MQTT_TOPIC_PREFIX")
    instance_id = _env("MQTT_INSTANCE_ID")
    poll_interval = float(_env("MQTT_POLL_INTERVAL", "3"))
    replay_window_seconds = int(_env("MQTT_REPLAY_WINDOW_SECONDS", "300"))
    ledger_path = Path(_env("MQTT_LEDGER_PATH", "/var/lib/mqtt-agent/tasks.jsonl"))
    max_workers = int(_env("MQTT_MAX_WORKERS", "4"))
    python_executable = _env("MQTT_PYTHON", "/usr/bin/python3")
    agent_cert = Path("/opt/mqtt-agent/agent-cert.pem")
    agent_key = Path("/opt/mqtt-agent/agent-key.pem")
    terraform_cert = Path("/opt/mqtt-agent/terraform-cert.pem")

    command_topic = f"{topic_prefix}/{instance_id}/command"
    result_topic = f"{topic_prefix}/{instance_id}/result"
    heartbeat_topic = f"{topic_prefix}/{instance_id}/heartbeat"

    completed, ledger_meta = _load_ledger(ledger_path)
    in_progress: set[str] = set()
    seen_nonces: set[str] = {item.get("nonce", "") for item in ledger_meta.values() if item.get("nonce")}
    lock = threading.Lock()
    executor = ThreadPoolExecutor(max_workers=max_workers)
    heartbeat_stop = threading.Event()

    client = mqtt.Client(client_id=f"mqtt-agent-{instance_id}", clean_session=True)
    client.tls_set()

    def publish_result(payload: dict[str, Any]) -> None:
        package_b64 = pack_message(
            payload,
            signer_cert_pem=agent_cert.read_text(encoding="utf-8"),
            signer_key_pem=agent_key.read_text(encoding="utf-8"),
            recipient_cert_pem=terraform_cert.read_text(encoding="utf-8"),
        )
        # retain=True allows exec.py to receive the result even if it connects after the command
        # completes, enabling idempotent re-runs.
        client.publish(result_topic, package_b64, qos=1, retain=True)

    def publish_heartbeat() -> None:
        """Publish periodic heartbeat message."""
        payload = {
            "message_type": "heartbeat",
            "task_uuid": "",
            "sent_at": _iso(_now_utc()),
            "nonce": "",
            "system_info": _get_system_info(),
        }
        package_b64 = pack_message(
            payload,
            signer_cert_pem=agent_cert.read_text(encoding="utf-8"),
            signer_key_pem=agent_key.read_text(encoding="utf-8"),
            recipient_cert_pem=terraform_cert.read_text(encoding="utf-8"),
        )
        client.publish(heartbeat_topic, package_b64, qos=1, retain=True)

    def heartbeat_loop() -> None:
        """Periodic heartbeat publishing thread."""
        while not heartbeat_stop.wait(timeout=10):  # publish every 10 seconds
            try:
                publish_heartbeat()
            except Exception:
                import traceback
                traceback.print_exc()

    def clear_retained_command() -> None:
        """Remove the retained command message so stale commands don't re-trigger after restart."""
        client.publish(command_topic, b"", qos=1, retain=True)

    def finish_task(task_uuid: str, record: dict[str, Any]) -> None:
        with lock:
            in_progress.discard(task_uuid)
            completed.add(task_uuid)
            ledger_meta[task_uuid] = record
            _append_ledger(ledger_path, record)

    def process_command(package_b64: str) -> None:
        if not package_b64.strip():
            # Empty payload is a retained-message-clear sentinel; ignore it.
            return

        payload = unpack_message(
            package_b64,
            recipient_cert_pem=agent_cert.read_text(encoding="utf-8"),
            recipient_key_pem=agent_key.read_text(encoding="utf-8"),
            expected_signer_cert_pem=terraform_cert.read_text(encoding="utf-8"),
        )

        if payload.get("message_type") != "command":
            raise RuntimeError("unexpected message type")

        task_uuid = payload["task_uuid"]
        nonce = payload["nonce"]
        sent_at = _parse_iso(payload["sent_at"])
        now = _now_utc()
        if abs((now - sent_at).total_seconds()) > replay_window_seconds:
            raise RuntimeError("command outside replay window")

        with lock:
            already_done = task_uuid in completed
            already_running = task_uuid in in_progress
            if not already_done and not already_running:
                if nonce in seen_nonces:
                    return
                in_progress.add(task_uuid)
                seen_nonces.add(nonce)

        if already_done:
            # Re-publish the stored result so exec.py gets it (idempotent re-run).
            stored = ledger_meta.get(task_uuid, {})
            result_payload = {
                "message_type": "result",
                "task_uuid": task_uuid,
                "nonce": stored.get("nonce", nonce),
                "sent_at": stored.get("sent_at", _iso(_now_utc())),
                "executed_at": stored.get("executed_at", _iso(_now_utc())),
                "status": stored.get("state", "success"),
                "exit_code": stored.get("exit_code", 0),
                "output": stored.get("output", ""),
            }
            publish_result(result_payload)
            clear_retained_command()
            return

        if already_running:
            return

        exit_code, output = _run_command(payload["command_type"], payload["command"])
        executed_at = _iso(_now_utc())
        state = "success" if exit_code == 0 else "failure"
        result_payload = {
            "message_type": "result",
            "task_uuid": task_uuid,
            "nonce": nonce,
            "sent_at": _iso(_now_utc()),
            "executed_at": executed_at,
            "status": state,
            "exit_code": exit_code,
            "output": output,
        }
        publish_result(result_payload)
        clear_retained_command()
        finish_task(
            task_uuid,
            {
                "task_uuid": task_uuid,
                "nonce": nonce,
                "state": state,
                "exit_code": exit_code,
                "output": output,
                "executed_at": executed_at,
                "sent_at": payload["sent_at"],
            },
        )

    def on_connect(client_obj: mqtt.Client, userdata: Any, flags: dict[str, Any], rc: int) -> None:
        client_obj.subscribe(command_topic, qos=1)
        print(f"[{_iso(_now_utc())}] connected rc={rc} topic={command_topic}", flush=True)

    def on_message(client_obj: mqtt.Client, userdata: Any, message: mqtt.MQTTMessage) -> None:
        package_b64 = message.payload.decode("utf-8")

        def _run() -> None:
            try:
                process_command(package_b64)
            except Exception:
                import traceback
                traceback.print_exc()

        executor.submit(_run)

    client.on_connect = on_connect
    client.on_message = on_message
    client.reconnect_delay_set(min_delay=1, max_delay=max(int(poll_interval), 5))
    client.connect(broker_host, broker_port, keepalive=60)
    client.loop_start()

    # Start heartbeat thread
    heartbeat_thread = threading.Thread(target=heartbeat_loop, daemon=True)
    heartbeat_thread.start()

    try:
        while True:
            time.sleep(poll_interval)
    except KeyboardInterrupt:
        return 0
    finally:
        heartbeat_stop.set()
        client.loop_stop()
        client.disconnect()
        executor.shutdown(wait=False, cancel_futures=True)


if __name__ == "__main__":
    raise SystemExit(main())
