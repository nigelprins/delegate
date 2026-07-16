#!/usr/bin/env python3
"""Shared helpers for Delegate Cursor hooks."""

from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

GATEWAY = os.environ.get("DELEGATE_GATEWAY", "http://127.0.0.1:43121")
CONFIG_CANDIDATES = [
    Path(os.environ["HOME"]) / ".delegate" / "config.json",
    Path(os.environ["HOME"]) / ".cursor" / "delegate.json",
]

SENSITIVE_MARKERS = (
    "/.env",
    "/.git/",
    "/.ssh/",
    "/.aws/",
    "/.gnupg/",
    "credentials",
    "id_rsa",
    "id_ed25519",
    ".pem",
    ".p12",
    ".key",
)


def load_token() -> str:
    token = os.environ.get("DELEGATE_TOKEN", "").strip()
    if token:
        return token
    for path in CONFIG_CANDIDATES:
        if not path.is_file():
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        candidate = str(data.get("pairingToken") or data.get("token") or "").strip()
        if candidate:
            return candidate
    return ""


def read_hook_input() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        return {}
    return json.loads(raw)


def emit(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload))
    sys.stdout.flush()


def deny(message: str) -> None:
    emit({"permission": "deny", "user_message": message})
    raise SystemExit(0)


def allow(message: str | None = None) -> None:
    payload: dict = {"permission": "allow"}
    if message:
        payload["user_message"] = message
    emit(payload)
    raise SystemExit(0)


def ask(message: str) -> None:
    emit({"permission": "ask", "user_message": message})
    raise SystemExit(0)


def looks_sensitive(path: str) -> bool:
    lowered = path.lower().replace("\\", "/")
    return any(marker in lowered for marker in SENSITIVE_MARKERS)


def evaluate(
    *,
    purpose: str,
    paths: list[str],
    content_sample: str = "",
    estimated_bytes: int,
    provider: str = "custom",
    endpoint: str = "https://api.openai.com/v1/responses",
    channel: str = "model",
) -> dict:
    token = load_token()
    if not token:
        raise RuntimeError(
            "Delegate pairing token missing. Copy it from the menu bar app into "
            "~/.delegate/config.json as {\"pairingToken\":\"…\"}."
        )
    payload = {
        "provider": provider,
        "endpoint": endpoint,
        "purpose": purpose,
        "paths": paths,
        "contentSample": content_sample[:4000],
        "estimatedBytes": max(estimated_bytes, 1),
        "approvedBytes": max(estimated_bytes, 1),
        "includesGitHistory": any("/.git/" in path.replace("\\", "/") for path in paths),
        "classification": "secret" if any(looks_sensitive(path) for path in paths) else "internalData",
        "channel": channel,
        "fileCount": max(len(paths), 1),
    }
    request = urllib.request.Request(
        f"{GATEWAY.rstrip('/')}/v1/evaluate",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Delegate-Token": token,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=4) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Delegate gateway HTTP {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"Delegate gateway unavailable: {error}") from error


def apply_verdict(decision: dict, *, fail_closed_message: str) -> None:
    verdict = decision.get("verdict", "deny")
    reasons = "; ".join(decision.get("reasons") or [fail_closed_message])
    if verdict == "allow":
        allow()
    if verdict == "ask":
        ask(reasons)
    deny(reasons)
