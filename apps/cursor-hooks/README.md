# Delegate Cursor hooks

These hooks make Cursor ask the local Delegate gateway before sensitive agent
actions. They use Cursor's native hook system — no Apple entitlement required.

## What they block

- reads of `.env`, `.git`, `.ssh`, `.aws`, credential files, and key material;
- high-risk shell patterns (`curl|sh`, `git bundle`, `.env` dumps, storage URLs);
- risky MCP payloads that look like uploads or secret exfiltration.

Ordinary source-file reads and normal shell commands stay local and fast.

## Install

1. Start the Delegate menu bar app and copy the pairing token.
2. Run:

```bash
zsh apps/cursor-hooks/install.sh
```

3. Edit `~/.delegate/config.json`:

```json
{
  "pairingToken": "your-token-here"
}
```

4. Restart Cursor or reopen the workspace.

Hooks are installed to:

- `~/.cursor/hooks.json`
- `~/.cursor/hooks/delegate_*.py`

## Fail-closed behavior

These hooks set `failClosed: true`. If Delegate is locked, missing a token, or
offline, risky actions are blocked instead of silently allowed.

## Optional

```bash
export DELEGATE_AUDIT_ALL_READS=1
```

routes every file read through the gateway, not only sensitive paths.
