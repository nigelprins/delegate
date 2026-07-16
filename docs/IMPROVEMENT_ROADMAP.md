# Delegate improvement roadmap

Research snapshot: July 2026. Sources include the current Delegate codebase,
OWASP Secure Coding with AI guidance, practitioner agent-hardening guides, and
the documented Grok Build whole-repo upload class of failure.

## Current position

Delegate is a trustworthy **explicit policy plane**:

- menu bar control center + local gateway;
- Chrome connector for selected chat text;
- isolated coding-agent runner;
- policy denials for secrets, Git history, storage/telemetry channels, and
  file-count explosions.

It is **not yet** a system-wide observer of every IDE or agent process.

## What the broader ecosystem confirms

1. **`.gitignore` is not an AI control.** Agents read the filesystem, not the Git
   index. Secrets on disk are context risks, not only commit risks.
2. **Ignore files help only partially.** `.cursorignore` / `.claudeignore` reduce
   passive indexing; agent shell access can still `cat` secrets.
3. **Whole-repo upload is a real failure mode.** Grok Build historically uploaded
   tracked repositories and history via a separate storage channel; training
   opt-out did not stop it.
4. **Least privilege beats clever detection.** Restrict workspace, block credential
   paths, require approval for risky tools, fail closed on security hooks.
5. **Prompt injection + secrets in context is the high-risk combo.** Repository
   content from untrusted PRs/issues should be treated as hostile input.
6. **Cursor hooks are the best near-term IDE enforcement point.** `beforeReadFile`,
   `beforeShellExecution`, and `beforeMCPExecution` can deny or ask before the
   agent acts, without Apple entitlements.

## Gap analysis

| Goal | Today | Gap |
| --- | --- | --- |
| See Cursor / VS Code / JetBrains | No | IDE connectors / hooks |
| See arbitrary processes | No | Endpoint Security + Network Extension |
| Stop whole-repo uploads | Runner + declared policy only | Honest clients only; no process attribution |
| Real byte budgets | Client can self-attest `approvedBytes` | Server-owned session budgets |
| Interactive approval | `ask` is logged, not approved | Menu-bar approve/deny RPC |
| Browser enforce | Toast only | Block paste/submit on deny |
| Secret hygiene | Regex + runner denylist | Stronger scanners, `.delegateignore`, secret-manager guidance |
| Auditability | Local encrypted ledger | Exportable decision log, signed sessions |

## Priority backlog

### P0 — make the existing plane honest

1. **Server-owned session budgets** — clients may propose size; the gateway decides
   the approved ceiling and remaining bytes.
2. **Fail closed when gateway is required** — Pause/unavailable should not silently
   mean “AI continues unprotected” for hooked clients.
3. **Interactive `ask` flow** — pending approvals in the menu bar with approve/deny
   that connectors can wait on.
4. **Stop treating equal `approvedBytes == estimatedBytes` as a real budget.**

### P1 — IDE coverage without Apple entitlements

1. **Cursor hooks package** — `beforeReadFile`, `beforeShellExecution`,
   `beforeMCPExecution` calling the local gateway with `failClosed: true`.
2. **VS Code / Cursor extension** — pairing, status, pending approvals, workspace
   session start.
3. **Shared connector protocol** — versioned envelope, session, and approval APIs.
4. **Project templates** — `.delegateignore`, recommended `.cursorignore`, sample
   hooks committed for adopters.

### P2 — stronger local prevention

1. Runner refuses whole-repo globs without explicit `--i-understand-broad-share`.
2. Runner optional network allowlist / HTTP proxy through Delegate.
3. Browser connector blocks clipboard helpers on deny.
4. Richer secret scanning aligned between Swift policy and Python runner.
5. Decision export (JSONL) for personal audits.

### P3 — system-wide coverage (Apple)

1. Endpoint Security entitlement application and prototype.
2. Network Extension content filter wired to signed session budgets.
3. Correlate declared IDE intent with observed file opens and outbound bytes.
4. Notarized release builds using Keychain instead of the development vault key.

## Design principles for the next iterations

- **Prevention over archaeology.** Prefer denying an upload to reconstructing it later.
- **Declare intent, then measure.** IDE hooks declare purpose and files; system
  monitors later verify the declaration.
- **No TLS interception.** Destination and volume metadata are enough for network
  enforcement; payload inspection stays on explicit samples.
- **Honest limitations.** Never market advisory connectors as system-wide coverage.
- **Fail closed for security hooks.** Crash/timeout of a security hook should block
  the risky action, not allow it.

## Immediate build sequence

1. Session budgets in the gateway.
2. Cursor hooks connector that evaluates sensitive reads/shell/MCP calls.
3. Protocol documentation for third-party connectors.
4. Interactive ask approvals in the menu bar.
5. Entitlement packaging plan for Network Extension / Endpoint Security.
