# Security policy

Delegate is security-sensitive software. Treat bypasses, secret exposure,
incorrect allow decisions, unsafe defaults, and privilege escalation as security
issues.

## Reporting a vulnerability

Do not open a public issue containing exploit details, credentials, private
repositories, or personal data.

Until GitHub private vulnerability reporting is enabled for this repository,
contact the maintainer through the private contact method on their GitHub profile.
Include:

- affected version or commit;
- expected and observed security boundary;
- minimal reproduction using fake data;
- impact and suggested mitigation, if known.

Never test Delegate against systems or data you do not own or have explicit
permission to use.

## Current boundary

The current MVP enforces requests submitted through its local gateway, browser
connector, and isolated agent runner. It does not yet claim universal visibility
into arbitrary IDE processes.

System-wide file-read attribution requires Apple's Endpoint Security entitlement.
System-wide per-process network enforcement requires a signed Network Extension.
The unsigned development build must not be presented as providing those controls.

## Supported versions

Only the latest commit on the default branch is supported during the pre-release
phase. No stable security SLA is offered yet.
