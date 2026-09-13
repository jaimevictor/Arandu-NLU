# ADR-0044: P14 user-directed transition to P15

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-10
- Owners: P14-P15, FINAL

## Context

ADR-0043 authorized one final P14 blocker-remediation baseline and required a
complete exact-subject gate plus six independent same-subject reviews before
P15 could begin.

The remediation was frozen at
`93ed8d75a4cb35f80572f8207105929b0071f48e`. Its pre-freeze focused checks
passed, but the exhaustive governance mutation suite was interrupted and the
clean exact-subject P14 gate and six-role review set were not run. The user
then explicitly directed the executor to move to P15 now.

## Decision

Record P14 as `COMPLETE_BY_USER_DIRECTED_TRANSITION`, not as
`PHASE_PASSED`, and activate P15 from the immutable `93ed8d75` baseline.

The transition carries these unresolved obligations:

- the complete clean exact-subject P14 gate;
- the exhaustive governance mutation suite;
- all six mandatory independent reviews of the P14 baseline;
- native Linux amd64 and aarch64 build, execution, isolation, and selected
  source reachability under ADR-0039; and
- real supported Home Assistant runtime execution under ADR-0040.

P15 may perform source discovery, evaluation, packaging implementation, and
non-release validation while that debt remains visible. It may not enable
release artifact production or either architecture, claim P14 passed, or
claim release readiness until the applicable debt passes or a newer explicit
user decision dispositions it.

The P14 source baseline remains immutable. Any later P0 through P2 finding
against it is recorded and handled under the owning phase's bounded workflow;
it is not silently treated as closed by this transition.

## Consequences

The project advances without misrepresenting the interrupted validation.
P15 begins with a larger fail-closed acceptance set and retains the existing
three-pass convergence and three-candidate limits.

## Rollback

If the carried validation exposes a blocker, keep artifact production and
architectures disabled, record the exact finding and baseline, and follow the
bounded P15 blocker process or request explicit scope adjudication when its
budget is exhausted.
