# ADR-0035: Terminal Validator And Evidence Closeout

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-31
- Owners: P13-P14
- Supersedes: ADR-0034 only for the terminal P13 blocker correction

## Context

Mandatory review of frozen P13 subject
`edf6e2c888c841c423f42a19c110072f3b6f7ec7` passed source licensing but
reproduced bounded P2 defects in source discovery, provenance, defensive
validation, governance parsing, and final correctness.

Leading or trailing Markdown whitespace and malformed IDs such as `USR_038`
could evade a decision parser. Wrapped or non-first-line origin statements
and the selected `Address::Constant arm copied from gimli` statement were
omitted, while unrelated later technical prose could suppress an earlier
origin witness. The vocabulary digest omitted rejection-regex options.

Two archive extractions used unbounded output capture. A descendant could
leave the child process group with `setsid`. Embedded YAML discovery could
repeat overlapping candidate work quadratically, and post-P00 `BLOCKED`
lifecycle fields were not mutually constrained.

These findings require no selected source, dependency, protocol, product, or
linguistic change.

## Decision

Both decision-row parsers MUST accept horizontal whitespace around the table
and delimiters, reject every malformed candidate `USR` row, and enforce the
complete contiguous ledger with `USR-038` as the current minimum floor.

Origin discovery MUST recognize the reproduced wrapped and selected source
statements. Rejection predicates MUST inspect only the matched statement, and
their source and options MUST be included in the vocabulary digest. Every new
real witness MUST receive the existing exact Rust source-rights disposition.

Archive listing and extraction children MUST consume output within recorded
limits and deadlines. Extraction is silent, so either output stream has a
zero-byte limit. Verified unprivileged children MUST run as process-group
leaders with a hard zero descendant-process limit; unsupported or privileged
execution MUST fail closed. Only the coordinator may signal an unreaped child
group.

Governance YAML candidate extraction MUST have linear reuse plus aggregate
candidate and byte limits. Every post-P00 lifecycle state MUST bind phase
identity, subject, checkpoints, findings, next action, and dependencies.
`BLOCKED` MUST identify a current-phase finding and explicit user scope
adjudication.

## Minimum Acceptance And Pass Limit

This is the blocker-only correction authorized by `USR-038`. Exact
regressions and the complete non-Cargo P13 gates MUST pass one immutable
subject. All five source reviewers and all seven phase reviewers MUST report
`PASS` on that same subject with no open P0 through P2 finding. The first
passing subject checkpoints immediately. No optional final review or
refinement pass is permitted.

## Consequences

P13 gains complete current decision discovery, statement-scoped origin
classification, semantic digest closure, bounded silent extraction,
descendant-resistant process containment, linear bounded YAML discovery, and
coherent blocked-state governance. P14 still owns native Linux source
reachability and product packaging.

## Rollback

Keep the transport candidate disabled and record P13 blocked if this bounded
replacement cannot pass its mandatory same-subject gates.
