# ADR-0043: Final P14 blocker remediation

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-10
- Owners: P14-FINAL

## Context

All six mandatory reviews of the ADR-0042 correction at
`e2ab301bad38caeaa2f32664bf442501eb8804df` returned `FAIL`. The immutable
blocker checkpoint at `aeac316eafa065b8c36fece92afa9c6b333c2eea`
records fourteen P0 through P2 classes.

ADR-0042 authorizes no further correction. The user explicitly authorized one
last bounded pass to correct those blockers and then move on.

## Decision

`USR-043` authorizes exactly one final integrated P14 blocker-remediation pass
limited to the fourteen IDs in
`docs/reviews/P14/blocker-summary.md` at the blocker checkpoint.

The pass may change only the adapter and companion operation-identity,
reconciliation, clock, epoch, and helper lifecycle behavior needed by those
blockers; their exact tests; and P14 governance, host-tool, Noise-promotion,
validation, and phase evidence. P13 remains byte-identical. The pass may not
add an optional feature, linguistic input, source selection, dependency,
weakened safety or privacy behavior, or claim a P15-transferred gate as
passed.

The pre-candidate pass unit is the one integrated correction approach selected
from the fourteen frozen blockers and then frozen, dispositioned, or rejected.
Minimum acceptance is:

- one exact regression for every blocker class;
- the complete exact-subject P14 gate and governance gate passing;
- no P13 byte change and no enabled artifact or architecture;
- no open P0 through P2 finding; and
- all six mandatory independent reviewers returning `PASS` for one immutable
  commit and tree.

The correction freezes once. A unanimous review set checkpoints P14
immediately and advances to P15. Any P0 through P2 finding records P14 as
terminally blocked without another correction.

## Consequences

This decision removes only ADR-0042's terminal stop for one pass. It restores
no ordinary candidate or refinement budget. P15, P16, and FINAL retain their
existing scopes and round caps.

## Rollback

If the final candidate does not meet minimum acceptance, retain the candidate,
gate evidence, and reports; record the terminal P14 blocker state; and do not
begin P15.
