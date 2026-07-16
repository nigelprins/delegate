#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from delegate_common import allow, apply_verdict, deny, evaluate, looks_sensitive, read_hook_input


def main() -> None:
    payload = read_hook_input()
    path = str(payload.get("file_path") or payload.get("path") or "")
    if not path:
        deny("Delegate blocked a file read without a path")

    audit_all = os.environ.get("DELEGATE_AUDIT_ALL_READS", "").lower() in {"1", "true", "yes"}
    if not looks_sensitive(path) and not audit_all:
        allow()

    try:
        size = Path(path).stat().st_size if Path(path).exists() else 4096
    except OSError:
        size = 4096

    try:
        decision = evaluate(
            purpose="Agent attempted to read a sensitive path",
            paths=[path],
            estimated_bytes=min(size, 256_000),
        )
    except RuntimeError as error:
        deny(str(error))
    apply_verdict(decision, fail_closed_message="Sensitive file read denied by Delegate")


if __name__ == "__main__":
    main()
