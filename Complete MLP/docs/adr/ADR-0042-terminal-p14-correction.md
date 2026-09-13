# ADR-0042: Terminal P14 correction

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-01
- Owners: P14-FINAL

## Context

All six mandatory reviews of the sole ADR-0041 correction at
`ba78fad6c7909c91efe32b5f11d221ae2a498a00` returned `FAIL`. The immutable
blocker checkpoint at `70a98ca89988c7d112e5b244673db443d9e46226`
records ten consolidated P1 and P2 classes.

ADR-0041 authorizes no second correction. The user explicitly authorized the
smallest bounded route that fixes the recorded defects and continues the
project.

## Decision

`USR-042` authorizes exactly one terminal integrated P14 correction limited to:

- duplicate-effect prevention and recoverable fail-closed reconciliation
  across runtime replacement and re-pair;
- bounded operation history and typed-session retention without treating an
  expired identity as new work;
- stop-time revocation, helper endpoint cleanup, and typed continuation when
  Home Assistant supplies no conversation ID;
- exact companion-test and Git-subject evidence binding;
- Git-reproducible Noise source mode identity; and
- exact regressions and governance evidence for those changes.

The correction may not add an optional feature, change linguistic input,
reopen source selection, modify P13, weaken safety, privacy, licensing,
provenance, clean-room, test, or review requirements, or claim either
P15-transferred runtime gate as passed.

The correction freezes once. All six mandatory P14 reviewers inspect that same
commit. A unanimous PASS checkpoints P14 immediately and advances to P15. Any
P0 through P2 finding returns P14 to `BLOCKED`; no additional correction or
optional review pass is authorized.

## Consequences

The authorization removes only the ADR-0041 terminal stop. It does not restore
an ordinary candidate budget. P15, P16, and FINAL retain their three-round
caps. Native Linux, real Home Assistant, artifact production, and architecture
admission remain disabled and P15-owned.

## Rollback

If the terminal candidate does not receive six mandatory PASS verdicts, retain
the failed candidate and reports, restore explicit P14 blocked state, and do
not begin P15.
