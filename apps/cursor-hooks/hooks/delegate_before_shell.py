#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from delegate_common import apply_verdict, deny, evaluate, read_hook_input

RISKY = re.compile(
    r"(curl\s+.*\|\s*(ba)?sh)"
    r"|(wget\s+.*\|\s*(ba)?sh)"
    r"|(\bscp\b|\brsync\b.+\s+\S+:)"
    r"|(\bgit\s+bundle\b)"
    r"|(\bcat\b.+\.env)"
    r"|(\bprintenv\b|\benv\b)"
    r"|(/v1/storage)"
    r"|(grok-code-session-traces)",
    re.IGNORECASE,
)


def main() -> None:
    payload = read_hook_input()
    command = str(payload.get("command") or payload.get("cmd") or "")
    if not command.strip():
        deny("Delegate blocked an empty shell command")

    if not RISKY.search(command):
        # Ordinary shell stays local; risky patterns go through Delegate.
        from delegate_common import allow

        allow()

    paths = [".env"] if ".env" in command else []
    channel = (
        "storage"
        if any(token in command.lower() for token in ("/v1/storage", "git bundle", "session-trace"))
        else "model"
    )
    try:
        decision = evaluate(
            purpose="Agent shell command matched a high-risk pattern",
            paths=paths,
            content_sample=command[:2000],
            estimated_bytes=max(len(command.encode("utf-8")), 8_000),
            endpoint="https://api.x.ai/v1/responses",
            provider="custom",
            channel=channel,
        )
    except RuntimeError as error:
        deny(str(error))
    apply_verdict(decision, fail_closed_message="Shell command denied by Delegate")


if __name__ == "__main__":
    main()
