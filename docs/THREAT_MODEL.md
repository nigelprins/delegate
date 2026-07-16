# Delegate threat model

## Goal

Delegate limits the data an AI tool can read or send, makes policy decisions
visible, and records why an action was allowed, questioned, or denied.

The central failure case is an agent receiving a narrow task while independently
reading or uploading a much broader workspace.

## Protected assets

- source files outside an explicitly approved scope;
- Git objects and repository history;
- credentials, tokens, private keys, and environment files;
- prompts, decisions, and local event history;
- network transfer beyond an approved destination and byte budget.

## Adversaries and failures

- a buggy or over-broad coding agent;
- a compromised provider client;
- hidden telemetry or trace upload paths;
- prompt injection requesting unrelated files;
- accidental user selection of sensitive content;
- unauthorized prompt or policy changes;
- malicious dependencies or contributors.

Delegate does not attempt to protect a fully compromised macOS administrator
account or hardware-level attacker.

## Enforcement levels

### Current

1. **Explicit gateway** — evaluates declared provider, endpoint, content sample,
   paths, Git-history flag, transfer channel, file count, and byte budget. An
   emergency lock keeps the gateway up and denies every transfer.
2. **Browser connector** — reads only explicit user selection on supported AI
   sites.
3. **Isolated runner** — copies an allowlisted, secret-scanned subset into a
   temporary workspace without `.git` or the user's real home directory, then
   reports the session envelope to the local gateway before launch.

These controls cannot observe an arbitrary IDE that was started outside Delegate.

### Required for system-wide coverage

1. **Endpoint Security system extension** — attribute file opens to a process and
   authorize sensitive reads.
2. **Network Extension content filter** — attribute outbound flows to a process,
   enforce destination policy, and stop transfers exceeding a signed byte budget.
3. **IDE connectors** — provide semantic intent such as the selected workspace,
   prompt, tool invocation, and expected files.

The system monitor correlates declared intent, actual file access, and outbound
network volume. OS metadata cannot reveal encrypted prompt contents and Delegate
must not perform TLS interception.

## Grok Build class of incident

The isolated runner mitigates whole-repository upload by ensuring the agent never
receives the original repository or Git database. Grok-specific telemetry and
codebase-upload flags are also disabled, but those flags are defense in depth,
not the primary boundary.

Future system-wide enforcement should alert and fail closed when:

- a coding process opens `.git`, credentials, or paths outside its approved root;
- the number of opened files materially exceeds declared intent;
- an AI process contacts an undeclared destination;
- outbound bytes exceed the approved envelope;
- policy or prompt hashes change without review.

## Non-goals

- claiming perfect secret detection from regular expressions;
- reading every IDE's proprietary encrypted traffic;
- silently intercepting TLS;
- reusing consumer AI subscriptions as API credentials;
- promising Apple system controls before required entitlements are granted.
