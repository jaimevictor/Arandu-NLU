# P14 Adapter And Companion Terminal Blocker Report

- Phase: `P14`
- State: `BLOCKED`
- Subject: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Ordinary candidate rounds consumed: `3 of 3`
- Exceptional blocker correction: `1 of 1 under USR-041`
- Terminal correction: `1 of 1 under USR-042`
- Mandatory reviews: `6 FAIL`
- Result: `TERMINAL_CORRECTION_REVIEW_FAIL`

## Candidate Result

The exact clean-subject gate passed with 132 companion tests, eight metadata
tests, 23 Noise packages, 218 passing Rust tests, three intentional ignores,
one harnessless pass, and 38 Clippy targets. Native Linux and real Home
Assistant execution remain transferred to P15, with both architectures and
artifact production disabled.

All six mandatory independent reviewers inspected the same exact subject and
returned `FAIL`. Primary-evidence counterexamples show that the green gate is
not sufficient for phase acceptance.

## Open Blockers

- `P14-P0-EXPIRED-REDISPATCH`: production emits `INITIAL`; after two retention
  cohorts, an expired identity is accepted as new and repeats an effect.
- `P14-P0-UNKNOWN-BARRIER-EVIDENCE`: unrelated already-satisfied state clears
  an unknown restart barrier and enables an unresolved effect.
- `P14-P1-MULTI-EFFECT-EVIDENCE`: one evidence slot cannot reconcile every
  effect in a multi-effect operation.
- `P14-P1-CLOCK-COHERENCE`: independent logical-time samplers permit rollback
  across boundaries and can expose raw clock exceptions.
- `P14-P1-RESTART-MARKER-DURABILITY`: failed persistence falls back only to
  memory and is lost on process reconstruction.
- `P14-P1-OLD-EPOCH-CONTINUATION`: a delayed helper reply can create
  continuation state after its epoch rotates.
- `P14-P1-GOVERNANCE-BINDING`: exact-subject normative governance validation
  uses a stale digest.
- `P14-P1-HOST-TOOL-ADMISSION`: validation-tool rights and shell admission
  evidence are incomplete.
- `P14-P1-HELPER-EXIT-ORACLE`: the process fake cannot detect cleanup before
  proven child exit.
- `P14-P2-RECONCILIATION-RECOVERY`: a mismatch denial is cached against the
  stable ID and cannot recover after live state changes.
- `P14-P2-RECONCILIATION-CAPACITY`: recovery can exceed or deadlock at the
  configured operation capacity.
- `P14-P2-PREPROOF-SOCKET`: helper failure before proof can leave its private
  endpoint and directory.
- `P14-P2-NOISE-REPORT-SCHEMA`: the promotion report does not bind its
  historical aggregate to a subject and digest schema.
- `P14-P2-SHARED-TOMBSTONE-ORACLE`: shared operation rotation lacks a
  multi-cohort regression.

## Bounded Stop

ADR-0042 and `USR-042` authorize no further P14 correction or optional review
round. Any P0 through P2 finding returns P14 to `BLOCKED`; this subject has
multiple independently reproduced findings, including P0 duplicate-effect
paths.

P15 has not started. The failed subject and reports are retained, P13 remains
closed, and the next permissible action is an explicit user scope decision.
