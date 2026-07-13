# Privacy

Delegate is local-first by design.

## Data stored locally

- policy decisions and recent security events;
- a random browser pairing token;
- development-vault key material for ad-hoc local builds.

The event vault is encrypted with AES-GCM. Ad-hoc development builds store their
random key in `~/Library/Application Support/Delegate` with user-only file
permissions. A future stably signed release will use macOS Keychain.

## Data sent externally

Delegate itself has no analytics or telemetry service. Text is evaluated locally
by the policy gateway. The current browser connector does not automatically scrape
full conversations and submits only text explicitly selected by the user.

If a user approves a request to a cloud AI provider, that provider's own privacy
terms apply. Consumer subscriptions and API access are separate services.

## Sensitive data

The policy engine attempts to block credential files, private keys, common token
formats, Git history, unknown endpoints, and transfers beyond an approved byte
budget. Pattern detection is defense in depth and cannot guarantee discovery of
every secret.

## Logs

Do not include real credentials, private source code, or personal data in public
issues. Use synthetic canary values when reporting security behavior.
