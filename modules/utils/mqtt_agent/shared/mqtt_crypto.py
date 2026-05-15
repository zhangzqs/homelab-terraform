#!/usr/bin/env python3
"""OpenSSL CMS helpers for MQTT command/result envelopes."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Any


def _write_file(path: Path, content: str | bytes) -> None:
    if isinstance(content, bytes):
        path.write_bytes(content)
    else:
        path.write_text(content, encoding="utf-8")


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _read_bytes(path: Path) -> bytes:
    return path.read_bytes()


def _run_openssl(args: list[str], input_bytes: bytes | None = None) -> bytes:
    proc = subprocess.run(
        ["openssl", *args],
        input=input_bytes,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.decode("utf-8", "replace").strip())
    return proc.stdout


def cert_fingerprint(cert_pem: str) -> str:
    with tempfile.TemporaryDirectory() as td:
        cert_path = Path(td) / "cert.pem"
        _write_file(cert_path, cert_pem)
        output = _run_openssl(["x509", "-in", str(cert_path), "-noout", "-fingerprint", "-sha256"])
        value = output.decode("utf-8").strip().split("=", 1)[1]
        return value.replace(":", "").upper()


def sign_payload(payload: bytes, signer_cert_pem: str, signer_key_pem: str) -> bytes:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        plain_path = td_path / "plain.json"
        cert_path = td_path / "signer-cert.pem"
        key_path = td_path / "signer-key.pem"
        signed_path = td_path / "signed.cms"
        _write_file(plain_path, payload)
        _write_file(cert_path, signer_cert_pem)
        _write_file(key_path, signer_key_pem)
        _run_openssl(
            [
                "cms",
                "-sign",
                "-binary",
                "-nodetach",
                "-in",
                str(plain_path),
                "-signer",
                str(cert_path),
                "-inkey",
                str(key_path),
                "-out",
                str(signed_path),
                "-outform",
                "PEM",
            ]
        )
        return _read_bytes(signed_path)


def encrypt_payload(signed_payload: bytes, recipient_cert_pem: str) -> bytes:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        signed_path = td_path / "signed.cms"
        cert_path = td_path / "recipient-cert.pem"
        encrypted_path = td_path / "encrypted.cms"
        _write_file(signed_path, signed_payload)
        _write_file(cert_path, recipient_cert_pem)
        _run_openssl(
            [
                "cms",
                "-encrypt",
                "-binary",
                "-aes256",
                "-in",
                str(signed_path),
                "-out",
                str(encrypted_path),
                "-outform",
                "PEM",
                str(cert_path),
            ]
        )
        return _read_bytes(encrypted_path)


def decrypt_payload(encrypted_payload: bytes, recipient_cert_pem: str, recipient_key_pem: str) -> bytes:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        encrypted_path = td_path / "encrypted.cms"
        cert_path = td_path / "recipient-cert.pem"
        key_path = td_path / "recipient-key.pem"
        decrypted_path = td_path / "decrypted.cms"
        _write_file(encrypted_path, encrypted_payload)
        _write_file(cert_path, recipient_cert_pem)
        _write_file(key_path, recipient_key_pem)
        _run_openssl(
            [
                "cms",
                "-decrypt",
                "-binary",
                "-inform",
                "PEM",
                "-in",
                str(encrypted_path),
                "-recip",
                str(cert_path),
                "-inkey",
                str(key_path),
                "-out",
                str(decrypted_path),
            ]
        )
        return _read_bytes(decrypted_path)


def verify_payload(signed_payload: bytes, expected_signer_cert_pem: str) -> bytes:
    expected_fp = cert_fingerprint(expected_signer_cert_pem)
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        signed_path = td_path / "signed.cms"
        signer_cert_path = td_path / "signer.pem"
        verified_path = td_path / "verified.json"
        _write_file(signed_path, signed_payload)
        _run_openssl(
            [
                "cms",
                "-verify",
                "-binary",
                "-inform",
                "PEM",
                "-in",
                str(signed_path),
                "-noverify",
                "-signer",
                str(signer_cert_path),
                "-out",
                str(verified_path),
            ]
        )
        actual_fp = cert_fingerprint(_read_text(signer_cert_path))
        if actual_fp != expected_fp:
            raise RuntimeError("Unexpected signer certificate")
        return _read_bytes(verified_path)


def pack_message(payload: dict[str, Any], signer_cert_pem: str, signer_key_pem: str, recipient_cert_pem: str) -> str:
    plain = json.dumps(payload, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    signed = sign_payload(plain, signer_cert_pem, signer_key_pem)
    encrypted = encrypt_payload(signed, recipient_cert_pem)
    return base64.b64encode(encrypted).decode("ascii")


def unpack_message(package_b64: str, recipient_cert_pem: str, recipient_key_pem: str, expected_signer_cert_pem: str) -> dict[str, Any]:
    encrypted = base64.b64decode(package_b64.encode("ascii"))
    signed = decrypt_payload(encrypted, recipient_cert_pem, recipient_key_pem)
    plain = verify_payload(signed, expected_signer_cert_pem)
    return json.loads(plain.decode("utf-8"))
