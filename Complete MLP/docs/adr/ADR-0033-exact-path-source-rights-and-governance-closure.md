# ADR-0033: Exact Path-Source Rights And Governance Closure

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-30
- Owners: P13-P14
- Supersedes: ADR-0032 only for the terminal P13 evidence correction

## Context

Independent audit of frozen P13 subject
`a4a4f904b68447abcc6d24f00fc87b6aba8634f3` reproduced six bounded
defects. Opening an untrusted FIFO could block before its type rejection.
Origin discovery omitted `based on`, `inspired by`, and non-first-line
`ported from`, while a Rust Unicode escape was falsely classified as CC0.
The selected sysroot observation included an Intel CPUID file with restrictive
terms and two LoongArch GCC headers whose exact GPL and runtime-exception
rights were not bound. Finally, `USR-019` through the current correction were
absent from requirement traceability and the source-convergence chronology was
stale.

These findings require no source-byte, transport, protocol, product, or
linguistic change.

## Decision

Large untrusted paths MUST be opened with no-follow and nonblocking flags, then
rejected unless the opened descriptor is a regular file with the exact
expected identity and bytes. Source-origin discovery MUST recognize the
reproduced vocabulary across every line and MUST distinguish literal CC0
evidence from a `\u{cc0}` source escape.

The exact Intel `cpuid.def` member is retained only as audit evidence and is
rejected from the product source closure. P14 MUST prove that native selected
builds cannot reach it. The two exact LoongArch headers are retained under
`GPL-3.0-or-later WITH GCC-exception-3.1`; their immutable hashes, the relevant
header statements, both legal texts, and SPDX license and exception records
MUST remain bound.

Every `USR-*` decision-table row MUST have one ordered traceability row and
manifest ID, with no gaps or extras. The chronology MUST identify every
post-budget correction authority through `USR-036`.

## Minimum Acceptance And Pass Limit

This is the blocker-only correction authorized by `USR-036`. Focused
regressions and the complete non-Cargo P13 gates MUST pass one immutable
subject. All mandatory source and phase reviewers MUST review that same
subject and report no open P0 through P2 finding. The first passing subject
checkpoints immediately. No optional final review or refinement pass is
permitted.

## Consequences

P13 gains fail-closed file opening, complete reproduced origin detection,
explicit rejected-source evidence, exact GPL/GCC-exception binding, and a
complete decision trace. P14 still owns kernel-enforced read-only native amd64
and aarch64 builds and proof that rejected source is unreachable.

## Rollback

Keep the transport candidate disabled and record P13 blocked if this bounded
replacement cannot pass its mandatory same-subject gates.
