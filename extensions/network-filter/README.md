# Delegate Network Filter

This directory contains the privileged, system-wide enforcement target.

It is deliberately not part of the unsigned Swift package. Apple requires a paid
Developer Program membership, a Network Extension provisioning profile, and the
`com.apple.developer.networking.networkextension` entitlement before a content
filter can be installed.

Once those are available:

1. Add a macOS Network Extension target in Xcode.
2. Use `FilterDataProvider.swift` as the data provider.
3. Add an App Group shared with the Delegate menu bar app.
4. Replace the temporary 1 MB flow limit with signed, per-request budgets from
   the local policy engine.
5. Add a filter control provider for process-level allow, ask, and deny rules.
6. Sign, notarize, and test on a non-production Mac before distribution.

The filter observes destination metadata and byte counts. It must not decrypt TLS.
Payload inspection and redaction stay in the explicit local gateway.
