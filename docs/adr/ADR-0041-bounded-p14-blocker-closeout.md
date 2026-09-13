# ADR-0041: Bounded P14 blocker closeout

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-01
- Owners: P14-FINAL

## Context

P14 exhausted its three declared candidate rounds. Mandatory review of
`ecaabc3c821fac093b1b4178f52c2ae4eccdfd79` reproduced two P0, five P1, and
five P2 blocker classes. The blocker checkpoint at
`745136a5c66f2b719683e15173614cd69349a0b9` stopped the phase under
`USR-010` and `USR-014`.

The user then directed the executor to continue the project. Advancing while
the findings remain open would violate the minimum acceptance contract.
Starting another ordinary refinement round would violate the candidate cap.

## Decision

`USR-041` authorizes exactly one exceptional integrated P14 blocker
correction. It is limited to:

- durable operation identity and fail-closed effect reconciliation across
  re-pair and runtime replacement;
- typed non-plan outcome routing, live catalog and capability membership, and
  final caller authorization at effect dispatch;
- rejected-connection retirement and bounded JSON failure handling;
- exact toolchain identity, complete changed-target coverage, strict suite
  evidence parsing, successful-output privacy scanning, and Noise file-mode
  binding; and
- exact regressions and the governance evidence needed to prove those changes.

The correction may not add an optional feature, reopen source selection,
weaken a safety, licensing, provenance, clean-room, or review requirement, or
claim either P15-transferred runtime gate as passed. P13 remains immutable.

The integrated correction freezes once. All six mandatory P14 reviewers inspect
that same commit. A unanimous PASS checkpoints P14 immediately and advances to
P15. Any P0 through P2 failure returns P14 to `BLOCKED`; no second exceptional
correction or optional review pass is authorized.

## Consequences

P14 receives one bounded way to satisfy rather than waive its minimum
acceptance contract. The ordinary three-candidate cap remains unchanged for
P15, P16, and FINAL. Native Linux, real Home Assistant, artifact production,
and architecture admission remain disabled and P15-owned under ADR-0039 and
ADR-0040.

## Rollback

If the correction cannot pass its mandatory same-subject reviews, retain the
failed subject and reports, restore the explicit P14 blocked state, and request
new user scope adjudication.
