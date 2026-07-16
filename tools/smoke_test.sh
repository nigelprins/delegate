#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
cd "$ROOT"

echo "==> Native policy checks"
swift run delegate-checks

echo "==> Isolated runner unit tests"
python3 tools/agent-runner/test_delegate_run.py

echo "==> Live gateway smoke (optional)"
TOKEN="${DELEGATE_TOKEN:-}"
if [[ -z "$TOKEN" ]]; then
  TOKEN="$(defaults read com.delegate.menubar pairingToken 2>/dev/null || true)"
fi

if [[ -z "$TOKEN" ]]; then
  echo "Skip live gateway: start Delegate.app and export DELEGATE_TOKEN, or open Connections once."
  exit 0
fi

python3 "$ROOT/tools/smoke_gateway.py" --token "$TOKEN"
echo "All smoke checks passed"
