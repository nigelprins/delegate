# Contributing to Delegate

Delegate welcomes focused issues and pull requests that improve its security
boundary, transparency, tests, provider adapters, and user experience.

## Before contributing

1. Do not include private repositories, real tokens, captured prompts, or personal
   data in issues, fixtures, commits, screenshots, or logs.
2. Use synthetic canaries for security tests.
3. Describe the exact guarantee being added or changed.
4. Distinguish observation, warning, and prevention in user-facing language.

## Local checks

```bash
swift build
swift run delegate-checks
python3 tools/agent-runner/test_delegate_run.py
npm --prefix apps/browser-extension ci
npm --prefix apps/browser-extension run typecheck
npm --prefix apps/browser-extension run build
```

Build the local macOS application bundle with:

```bash
zsh tools/build_macos_app.sh
```

## Pull requests

- Keep changes small and reviewable.
- Add regression coverage for policy or security changes.
- Document new permissions, data flows, and external destinations.
- Never weaken a deny rule silently.
- Mark limitations explicitly.

Security vulnerabilities should follow `SECURITY.md`, not the public issue tracker.
