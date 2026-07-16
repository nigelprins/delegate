#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from delegate_common import allow, apply_verdict, deny, evaluate, looks_sensitive, read_hook_input


def main() -> None:
    payload = read_hook_input()
    tool = str(payload.get("tool_name") or payload.get("tool") or "mcp")
    args = payload.get("arguments") or payload.get("args") or {}
    sample = args if isinstance(args, str) else json.dumps(args)[:2000]
    lowered = sample.lower()
    risky = any(
        marker in lowered
        for marker in (
            "/v1/storage",
            "git bundle",
            "upload",
            "telemetry",
            ".env",
            "password",
            "api_key",
            "private_key",
        )
    ) or looks_sensitive(sample)
    if not risky:
        allow()

    channel = "storage" if any(
        marker in lowered for marker in ("/v1/storage", "git bundle", "upload", "telemetry")
    ) else "model"

    try:
        decision = evaluate(
            purpose=f"Agent MCP tool invocation: {tool}",
            paths=[],
            content_sample=sample,
            estimated_bytes=max(len(sample.encode("utf-8")), 4_096),
            provider="custom",
            channel=channel,
        )
    except RuntimeError as error:
        deny(str(error))
    apply_verdict(decision, fail_closed_message="MCP tool call denied by Delegate")


if __name__ == "__main__":
    main()
