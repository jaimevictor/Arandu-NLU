# ADR-0034: Bounded Source-Review Closeout

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-30
- Owners: P13-P14
- Supersedes: ADR-0033 only for the terminal P13 evidence correction

## Context

Independent review of frozen P13 subject
`89cb007efc15a67b3f2c9af1af8973a7026538fa` reproduced five bounded P2
classes. A mixed nonstandard and origin witness could be assigned a globally
valid but weaker origin disposition. Source scanning omitted bare `Based on`,
wrapped comment-prefix `based on`, and non-first-line bare `Copied from`
statements, including current selected Rust path-source bytes. Archive listing
was limited only after `capture3` buffered complete output. Finally, harmless
Markdown whitespace could hide a decision row from both governance parsers,
while a fixed current-decision ceiling rejected a future contiguous row.

These findings require no source-byte, transport, protocol, product, or
linguistic change.

## Decision

Witness dispositions MUST enforce this precedence:
`RESTRICTIVE/NONSTANDARD > ORIGIN > ALTERNATIVE > PERMISSIVE`. A tuple valid
for a lower class MUST fail when a higher-class witness exists.

Origin discovery MUST recognize the reproduced bare, wrapped, and
non-first-line comment forms across every selected file. The resulting exact
witness inventory and every affected disposition MUST remain hash-bound.

Archive-listing standard output and standard error MUST each be consumed
through the recorded byte limit. The child MUST be terminated as soon as
either stream exceeds its limit; complete untrusted output MUST NOT be
buffered before enforcement.

Decision and traceability row discovery MUST accept horizontal delimiter
whitespace, reject malformed candidate ID rows, require contiguous ordered
IDs, and treat `USR-037` as a minimum current floor rather than a maximum
future ceiling.

## Minimum Acceptance And Pass Limit

This is the blocker-only correction authorized by `USR-037`. Exact regressions
and the complete non-Cargo P13 gates MUST pass one immutable subject. All five
source reviewers and all seven phase reviewers MUST report `PASS` on that
same subject with no open P0 through P2 finding. The first passing subject
checkpoints immediately. No optional final review or refinement pass is
permitted.

## Consequences

P13 gains precedence-bound rights dispositions, complete reproduced current
origin coverage, bounded archive-listing memory, and future-safe governance
row discovery. P14 still owns native Linux reachability, packaging, adapter
runtime, and proof that rejected Intel source is unreachable.

## Rollback

Keep the transport candidate disabled and record P13 blocked if this bounded
replacement cannot pass its mandatory same-subject gates.
