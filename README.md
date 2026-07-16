# Delegate

Delegate is a local-first safety boundary for AI tools. It makes data sharing
explicit, blocks secrets and repository history, records policy decisions in an
encrypted local vault, and exposes controls from the macOS menu bar.

> **Pre-release:** Delegate does not yet provide universal visibility into every
> IDE process. Cursor hooks and the connector protocol are the supported near-term
> path. Read the security boundary and
> [`docs/IMPROVEMENT_ROADMAP.md`](docs/IMPROVEMENT_ROADMAP.md) before relying on it.

## What works in this MVP

- Native SwiftUI menu bar control center with emergency **Block all** lock.
- Authenticated policy gateway at `http://127.0.0.1:43121`.
- AES-GCM event vault. Ad-hoc development builds use a permission-locked local
  key to avoid false Keychain trust prompts; a stable signed release uses Keychain.
- Secret, credential-file, Git-history, endpoint, upload-budget, storage/telemetry
  channel, and file-count explosion checks.
- Chrome side panel and in-page connector for ChatGPT, Claude, and Grok.
- Isolated coding-agent runner that exposes only approved files, reports to the
  local gateway, and uses a temporary HOME without `.git` history.
- Grok Build hardening flags in every isolated run.
- Server-owned session budgets so clients cannot self-approve unlimited uploads.
- Cursor hooks package for sensitive file reads, risky shell, and MCP calls.
- Network Extension source scaffold for later signed system-wide enforcement.

## Run the menu bar app

```bash
zsh tools/build_macos_app.sh
open .build/Delegate.app
```

The app appears as a shield in the macOS menu bar. Open Connections and copy its
pairing token.

## Build the browser connector

```bash
cd apps/browser-extension
npm install
npm run typecheck
npm run build
```

Load `apps/browser-extension/dist` as an unpacked extension in Chrome, open its
side panel, and paste the pairing token. On supported AI sites, select text and
press the Delegate button in the lower-right corner.

## Run a coding agent safely

The runner copies an explicit allowlist to a temporary workspace. It excludes
Git metadata, credential files, symlinks, oversized files, and likely secrets.

```bash
export DELEGATE_TOKEN="$(defaults read com.delegate.menubar pairingToken)"
python3 tools/agent-runner/delegate_run.py \
  --include "Sources/**" \
  --include "Package.swift" \
  --purpose "Review selected Swift sources" \
  -- grok -p "Review this code"
```

Use `--yes` only in automation after reviewing the include patterns. Pass
`--skip-gateway` only when the menu bar app is not running.

## Install Cursor hooks

```bash
zsh apps/cursor-hooks/install.sh
```

Paste the menu bar pairing token into `~/.delegate/config.json`, then restart
Cursor. Details: [`apps/cursor-hooks/README.md`](apps/cursor-hooks/README.md).

## Smoke test

```bash
zsh tools/smoke_test.sh
```

With Delegate.app running, the script also hits the live gateway with allow and
deny cases inspired by whole-repo upload failures.

## Security boundary

Configured browser and API clients are enforced now. The isolated runner protects
coding sessions by removing access to the original repository. Delegate cannot
yet attribute arbitrary file reads and network traffic from every unrelated
process. That requires Apple's approved Endpoint Security entitlement and a
signed Network Extension. The network-filter scaffold is under
`extensions/network-filter`; the complete design is in
[`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md).

Consumer ChatGPT, Claude, and Grok subscriptions are separate from provider API
access. Delegate never claims or attempts to reuse those subscriptions as API
credentials.

## Contributing and privacy

- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)
- [`PRIVACY.md`](PRIVACY.md)
- [`docs/THREAT_MODEL.md`](docs/THREAT_MODEL.md)
- [`docs/IMPROVEMENT_ROADMAP.md`](docs/IMPROVEMENT_ROADMAP.md)
- [`docs/CONNECTOR_PROTOCOL.md`](docs/CONNECTOR_PROTOCOL.md)

Licensed under the [Apache License 2.0](LICENSE).
