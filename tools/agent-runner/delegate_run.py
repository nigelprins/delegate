#!/usr/bin/env python3
"""Run an AI coding tool against an explicit, sanitized workspace snapshot."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

MAX_FILE_BYTES = 10 * 1024 * 1024
SENSITIVE_NAMES = {
    ".env",
    ".git",
    ".netrc",
    "credentials.json",
    "id_rsa",
    "id_ed25519",
}
SENSITIVE_SUFFIXES = {".key", ".pem", ".p12", ".pfx"}
SECRET_MARKERS = (
    "-----BEGIN PRIVATE KEY-----",
    "-----BEGIN RSA PRIVATE KEY-----",
    "AKIA",
    "api_key=",
    "apikey=",
    "password=",
    "secret=",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Expose only explicitly included, secret-scanned files to an AI coding agent. "
            "Git metadata and your real HOME are never mounted."
        )
    )
    parser.add_argument(
        "--include",
        action="append",
        required=True,
        help="Relative glob to include; repeat for multiple globs.",
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=Path.cwd(),
        help="Source workspace (default: current directory).",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Run after printing the manifest without an interactive confirmation.",
    )
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("provide an agent command after --")
    return args


def is_sensitive(path: Path) -> bool:
    lowered = [part.lower() for part in path.parts]
    return (
        any(part in SENSITIVE_NAMES or part.startswith(".env.") for part in lowered)
        or path.suffix.lower() in SENSITIVE_SUFFIXES
    )


def matches(path: Path, patterns: list[str]) -> bool:
    relative = path.as_posix()
    return any(
        fnmatch.fnmatch(relative, pattern)
        or fnmatch.fnmatch(path.name, pattern)
        or (pattern.endswith("/**") and relative.startswith(pattern[:-3]))
        for pattern in patterns
    )


def contains_secret(path: Path) -> bool:
    try:
        sample = path.read_bytes()[:256_000]
        text = sample.decode("utf-8", errors="ignore").lower()
    except OSError:
        return True
    return any(marker.lower() in text for marker in SECRET_MARKERS)


def collect(root: Path, patterns: list[str]) -> list[Path]:
    selected: list[Path] = []
    for path in root.rglob("*"):
        if (
            not path.is_file()
            or path.is_symlink()
            or not matches(path.relative_to(root), patterns)
            or is_sensitive(path.relative_to(root))
        ):
            continue
        if path.stat().st_size > MAX_FILE_BYTES:
            print(f"blocked oversized file: {path.relative_to(root)}", file=sys.stderr)
            continue
        if contains_secret(path):
            print(f"blocked possible secret: {path.relative_to(root)}", file=sys.stderr)
            continue
        selected.append(path)
    return sorted(selected)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]


def harden_grok(home: Path) -> None:
    config_dir = home / ".grok"
    config_dir.mkdir(parents=True)
    (config_dir / "config.toml").write_text(
        "[harness]\n"
        "disable_codebase_upload = true\n\n"
        "[features]\n"
        "telemetry = false\n\n"
        "[telemetry]\n"
        "trace_upload = false\n",
        encoding="utf-8",
    )


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    files = collect(root, args.include)
    if not files:
        print("No safe files matched. Nothing was shared.", file=sys.stderr)
        return 2

    total = sum(path.stat().st_size for path in files)
    print(f"Delegate will expose {len(files)} files ({total:,} bytes), without .git history:")
    for path in files:
        print(f"  {path.relative_to(root)}  sha256:{digest(path)}")

    if not args.yes:
        answer = input("Continue? [y/N] ").strip().lower()
        if answer not in {"y", "yes"}:
            return 1

    with tempfile.TemporaryDirectory(prefix="delegate-agent-") as temporary:
        base = Path(temporary)
        workspace = base / "workspace"
        home = base / "home"
        workspace.mkdir()
        home.mkdir()

        for source in files:
            destination = workspace / source.relative_to(root)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
        harden_grok(home)

        environment = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": str(home),
            "TMPDIR": str(base / "tmp"),
            "DELEGATE_ISOLATED": "1",
            "DELEGATE_APPROVED_BYTES": str(total),
            "GROK_TELEMETRY_TRACE_UPLOAD": "false",
            "GROK_TELEMETRY_ENABLED": "false",
        }
        Path(environment["TMPDIR"]).mkdir()
        result = subprocess.run(args.command, cwd=workspace, env=environment, check=False)
        return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
