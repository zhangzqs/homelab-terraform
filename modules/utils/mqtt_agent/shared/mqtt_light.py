#!/usr/bin/env python3
"""Minimal MQTT v3.1.1 client (TLS + publish/subscribe) built on Python stdlib."""

from __future__ import annotations

import os
import socket
import ssl
import struct
import threading
import time
from dataclasses import dataclass
from typing import Any


def _encode_varint(value: int) -> bytes:
    out = bytearray()
    while True:
        byte = value % 128
        value //= 128
        if value > 0:
            byte |= 0x80
        out.append(byte)
        if value == 0:
            break
    return bytes(out)


def _decode_varint(sock: socket.socket) -> int:
    multiplier = 1
    value = 0
    while True:
        byte = sock.recv(1)
        if not byte:
            raise ConnectionError("mqtt connection closed")
        digit = byte[0]
        value += (digit & 0x7F) * multiplier
        if (digit & 0x80) == 0:
            return value
        multiplier *= 128
        if multiplier > 128 * 128 * 128:
            raise RuntimeError("malformed mqtt remaining length")


def _recv_exact(sock: socket.socket, n: int) -> bytes:
    out = bytearray()
    while len(out) < n:
        chunk = sock.recv(n - len(out))
        if not chunk:
            raise ConnectionError("mqtt connection closed")
        out.extend(chunk)
    return bytes(out)


def _pack_utf8(value: str) -> bytes:
    raw = value.encode("utf-8")
    return struct.pack("!H", len(raw)) + raw


@dataclass
class MQTTMessage:
    topic: str
    payload: bytes


class Client:
    def __init__(self, callback_api_version: Any = None, client_id: str | None = None, clean_session: bool = True):
        self.client_id = client_id or f"mqtt-light-{os.urandom(4).hex()}"
        self.clean_session = clean_session
        self.keepalive = 60
        self.host = ""
        self.port = 1883
        self.sock: socket.socket | None = None
        self.on_connect = None
        self.on_message = None
        self._tls_enabled = False
        self._tls_ctx = ssl.create_default_context()
        self._stop = threading.Event()
        self._loop_thread: threading.Thread | None = None
        self._send_lock = threading.Lock()
        self._packet_id = 0
        self._reconnect_min = 1
        self._reconnect_max = 5
        self._last_sent = time.monotonic()

    def tls_set(self, *args: Any, **kwargs: Any) -> None:
        self._tls_enabled = True

    def tls_insecure_set(self, value: bool) -> None:
        if value:
            self._tls_ctx.check_hostname = False
            self._tls_ctx.verify_mode = ssl.CERT_NONE

    def reconnect_delay_set(self, min_delay: int = 1, max_delay: int = 5) -> None:
        self._reconnect_min = max(1, int(min_delay))
        self._reconnect_max = max(self._reconnect_min, int(max_delay))

    def _next_packet_id(self) -> int:
        self._packet_id += 1
        if self._packet_id > 0xFFFF:
            self._packet_id = 1
        return self._packet_id

    def _send(self, data: bytes) -> None:
        if self.sock is None:
            raise ConnectionError("mqtt not connected")
        with self._send_lock:
            self.sock.sendall(data)
            self._last_sent = time.monotonic()

    def connect(self, host: str, port: int, keepalive: int = 60) -> int:
        self.host = host
        self.port = int(port)
        self.keepalive = int(keepalive)
        self._connect_socket()
        return 0

    def _connect_socket(self) -> None:
        raw = socket.create_connection((self.host, self.port), timeout=30)
        raw.settimeout(10)
        self.sock = self._tls_ctx.wrap_socket(raw, server_hostname=self.host) if self._tls_enabled else raw

        payload = (
            _pack_utf8("MQTT")
            + bytes([4, (0x02 if self.clean_session else 0x00)])
            + struct.pack("!H", self.keepalive)
            + _pack_utf8(self.client_id)
        )
        self._send(b"\x10" + _encode_varint(len(payload)) + payload)

        fixed = _recv_exact(self.sock, 1)
        if fixed[0] != 0x20:
            raise RuntimeError("expected CONNACK")
        remaining = _decode_varint(self.sock)
        body = _recv_exact(self.sock, remaining)
        rc = body[1] if len(body) >= 2 else 255
        if rc != 0:
            raise RuntimeError(f"mqtt connect rejected rc={rc}")
        if self.on_connect is not None:
            self.on_connect(self, None, {}, rc)

    def disconnect(self) -> None:
        if self.sock is not None:
            try:
                self._send(b"\xE0\x00")
            except Exception:
                pass
            try:
                self.sock.close()
            finally:
                self.sock = None

    def subscribe(self, topic: str, qos: int = 0) -> None:
        pid = self._next_packet_id()
        body = struct.pack("!H", pid) + _pack_utf8(topic) + bytes([qos & 0x01])
        self._send(b"\x82" + _encode_varint(len(body)) + body)

    def publish(self, topic: str, payload: str | bytes, qos: int = 0, retain: bool = False) -> None:
        if isinstance(payload, str):
            payload_bytes = payload.encode("utf-8")
        else:
            payload_bytes = payload
        qos = 1 if int(qos) > 0 else 0
        flags = (0x02 if qos == 1 else 0x00) | (0x01 if retain else 0x00)
        header = 0x30 | flags
        var_header = _pack_utf8(topic)
        if qos == 1:
            var_header += struct.pack("!H", self._next_packet_id())
        body = var_header + payload_bytes
        self._send(bytes([header]) + _encode_varint(len(body)) + body)

    def loop_start(self) -> None:
        if self._loop_thread and self._loop_thread.is_alive():
            return
        self._stop.clear()
        self._loop_thread = threading.Thread(target=self._loop, daemon=True)
        self._loop_thread.start()

    def loop_stop(self) -> None:
        self._stop.set()
        if self._loop_thread is not None:
            self._loop_thread.join(timeout=3)
        self._loop_thread = None

    def _handle_packet(self) -> None:
        if self.sock is None:
            raise ConnectionError("mqtt not connected")
        first = _recv_exact(self.sock, 1)[0]
        packet_type = first >> 4
        flags = first & 0x0F
        remaining = _decode_varint(self.sock)
        body = _recv_exact(self.sock, remaining)

        if packet_type == 3:  # PUBLISH
            topic_len = struct.unpack("!H", body[:2])[0]
            topic = body[2 : 2 + topic_len].decode("utf-8", "replace")
            index = 2 + topic_len
            qos = (flags >> 1) & 0x03
            packet_id = None
            if qos > 0:
                packet_id = struct.unpack("!H", body[index : index + 2])[0]
                index += 2
            payload = body[index:]
            if qos == 1 and packet_id is not None:
                self._send(b"\x40\x02" + struct.pack("!H", packet_id))
            if self.on_message is not None:
                self.on_message(self, None, MQTTMessage(topic=topic, payload=payload))
            return

        if packet_type == 13:  # PINGRESP
            return

        # SUBACK/PUBACK and others are intentionally ignored by this minimal client.

    def _loop(self) -> None:
        reconnect_delay = self._reconnect_min
        while not self._stop.is_set():
            try:
                if self.sock is None:
                    self._connect_socket()
                    reconnect_delay = self._reconnect_min

                if time.monotonic() - self._last_sent >= max(5, self.keepalive // 2):
                    self._send(b"\xC0\x00")  # PINGREQ

                self._handle_packet()
            except (OSError, ConnectionError, ssl.SSLError):
                self.disconnect()
                if self._stop.wait(timeout=reconnect_delay):
                    break
                reconnect_delay = min(self._reconnect_max, max(self._reconnect_min, reconnect_delay * 2))
            except Exception:
                self.disconnect()
                if self._stop.wait(timeout=reconnect_delay):
                    break
                reconnect_delay = min(self._reconnect_max, max(self._reconnect_min, reconnect_delay * 2))
