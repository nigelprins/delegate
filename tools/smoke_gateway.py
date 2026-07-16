#!/usr/bin/env python3
"""Exercise the live local Delegate gateway with allow and deny cases."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request

GATEWAY = "http://127.0.0.1:43121"


def post(token: str, payload: dict) -> dict:
    request = urllib.request.Request(
        f"{GATEWAY}/v1/evaluate",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "X-Delegate-Token": token,
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.loads(response.read().decode("utf-8"))


def expect(token: str, name: str, payload: dict, verdict: str) -> None:
    decision = post(token, payload)
    got = decision.get("verdict")
    if got != verdict:
        reasons = "; ".join(decision.get("reasons", []))
        raise AssertionError(f"{name}: expected {verdict}, got {got} ({reasons})")
    print(f"PASS  gateway {name} -> {verdict}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--token", required=True)
    args = parser.parse_args()

    try:
        with urllib.request.urlopen(f"{GATEWAY}/health", timeout=3) as response:
            health = json.loads(response.read().decode("utf-8"))
    except urllib.error.URLError as error:
        print(f"Gateway offline: {error}", file=sys.stderr)
        return 2

    print(f"Gateway health: {health.get('status')} v{health.get('version', '?')}")

    expect(
        args.token,
        "safe local model",
        {
            "provider": "ollama",
            "endpoint": "http://127.0.0.1:11434/api/chat",
            "purpose": "Summarize selected text",
            "paths": [],
            "contentSample": "Public release notes",
            "estimatedBytes": 120,
            "approvedBytes": 500,
            "includesGitHistory": False,
            "classification": "publicData",
            "channel": "model",
            "fileCount": 0,
        },
        "allow",
    )
    expect(
        args.token,
        "grok storage upload",
        {
            "provider": "xAI",
            "endpoint": "https://api.x.ai/v1/storage",
            "purpose": "Reply OK, do not read any files",
            "paths": ["src/a.py", "src/b.py"],
            "contentSample": "bundle",
            "estimatedBytes": 5_000_000,
            "approvedBytes": 1_000,
            "includesGitHistory": True,
            "classification": "internalData",
            "channel": "storage",
            "fileCount": 298,
        },
        "deny",
    )
    expect(
        args.token,
        "secret in selection",
        {
            "provider": "openAI",
            "endpoint": "https://api.openai.com/v1/responses",
            "purpose": "Capture selected text",
            "paths": [],
            "contentSample": "export OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz012345",
            "estimatedBytes": 80,
            "approvedBytes": 80,
            "includesGitHistory": False,
            "classification": "secret",
            "channel": "model",
        },
        "deny",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
