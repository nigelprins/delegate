# Delegate connector protocol

Base URL: `http://127.0.0.1:43121`

All mutating routes require header:

```http
X-Delegate-Token: <pairing-token>
```

The pairing token is copied from the Delegate menu bar app under Connections.

## Health

```http
GET /health
```

Unauthenticated. Example:

```json
{ "status": "protected", "version": "0.2.0" }
```

Statuses: `protected`, `locked`, or unreachable.

## Start a session

```http
POST /v1/sessions
Content-Type: application/json
```

```json
{
  "purpose": "Review authentication module",
  "approvedBytes": 250000,
  "maxFiles": 25,
  "roots": ["Sources/Auth"]
}
```

Response:

```json
{
  "sessionId": "…",
  "approvedBytes": 250000,
  "maxFiles": 25,
  "remainingBytes": 250000
}
```

The gateway owns the budget. Clients may propose values; Delegate clamps them to
local policy defaults.

## Evaluate a transfer

```http
POST /v1/evaluate
Content-Type: application/json
```

```json
{
  "sessionId": "optional-session-id",
  "provider": "xAI",
  "endpoint": "https://api.x.ai/v1/responses",
  "purpose": "Read selected files for review",
  "paths": ["Sources/Auth/Login.swift"],
  "contentSample": "optional text sample",
  "estimatedBytes": 12000,
  "approvedBytes": 12000,
  "includesGitHistory": false,
  "classification": "internalData",
  "channel": "model",
  "fileCount": 1
}
```

Notes:

- `approvedBytes` from the client is a proposal. When a `sessionId` is present,
  the session budget wins.
- When no session exists, the gateway applies a default ceiling.
- `channel` should be `model`, `storage`, or `telemetry`. Storage/telemetry is
  denied by default.

Response:

```json
{
  "verdict": "allow" | "ask" | "deny",
  "reasons": ["…"],
  "redactions": ["sk-a…z012"]
}
```

Connector behavior:

| Verdict | Required client behavior |
| --- | --- |
| `allow` | Proceed |
| `ask` | Wait for explicit user approval; do not send data yet |
| `deny` | Block the action and show `reasons` |

Security hooks should use fail-closed behavior: if the gateway is unreachable,
block the risky action.

## Providers

`openAI` · `anthropic` · `xAI` · `ollama` · `custom`
