# P12 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `01a04bd7-4f31-7ed3-bb88-49ad01155093`
- Input commit: `e1146f920a8997ff9985bff494e44813817426c9`
- Input tree: `de3042a725e7589d4185be86f0f2a14fa183e205`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SCOPE_SELECTED`

## Mandatory Scope

P12 closes exactly 19 directly owned requirements:

- `GLB-SESSION-001..003`;
- `ARC-DIALOG-001`; and
- `P12-SES-001..015`.

The minimum result stores one bounded pending entity continuation per opaque
session, expires it through injected logical time, binds it to one invocation
origin, capability, slot, catalog generation, and bounded typed referent set,
and permits at most one atomic completion or cancellation.

P12 exercises its component-level slice of `GLB-SAFE-001..003`,
`GLB-DET-001..003`, `GLB-SEM-001..007`, `GLB-SCOPE-003`,
`GLB-PRIV-001`, `GLB-PRIV-003`, `GLB-PRIV-009`,
`GLB-SEC-009..011`, and `GLB-ADAPT-019`. Those shared requirements remain
pending for their release-level owners.

## Existing Gap

P10 `EntityClarification` contains candidate matches but not the unresolved
slot or originating capability. P11 returns that bare clarification and loses
the other validated bindings needed to finish the complete plan safely.
Protocol v1 has no continuation contract.

P12 therefore adds a separate resumable P11 path. It retains the exact
validated source, graph shape, resolved bindings, unresolved endpoint,
capability, catalog generation, and candidate `EntityRef` values. Completion
consumes that record and can fill only its recorded endpoint.

No external or linguistic source is required. Runtime output cannot establish
gold labels, and held-out records remain inaccessible.

## Minimum Acceptance

P12 is minimally acceptable only when:

- all 19 directly owned requirements have reproducible tests;
- the exact TTL boundary, zero TTL, deadline overflow, and clock rollback fail
  closed;
- live sessions pass at 64 and reject 65, and referents pass at 16 and reject
  17 without eviction or truncation;
- session, origin, capability, endpoint, option, and catalog-generation
  substitutions produce no plan;
- replay, cancellation, expiry, invalid selection, and stale generation leave
  no reusable continuation;
- an unresolved tie never selects a default candidate;
- deterministic schedule permutations and a real concurrent double-take
  produce at most one plan;
- restart-empty and privacy tests prove in-memory, redacted state;
- protocol v1 and inherited P10/P11 behavior remain unchanged;
- focused tests, strict clippy, locked build/test, source/license/privacy
  checks, and inherited gates pass;
- every mandatory reviewer passes the same immutable subject with no open
  P0-P2; and
- the evidence checkpoint validates.

## Deferred Shared Work

`P12-SES-016` receives a memory-only implementation now, but packaged
restart/filesystem evidence remains P14-owned. `P12-COMPAT-001..005` execute
in P13 before transport freeze, and `P12-COMPAT-006` remains P14-owned.
Caller, pairing epoch, peer restart, and pre-execution stale checks in
`P12-SES-017..020` require the P13/P14 adapter contracts and are not
represented by placeholder authority in P12.

## Bounded Convergence

One convergence pass is one selected and dispositioned tuple of resumable P11
contract, session schema, limits, time rules, atomic store, schedule model,
and test portfolio. This is pass 1 of at most 3. Candidate round 1 freezes the
first implementation meeting the minimum; later passes and rounds are
blocker-only and do not authorize optional refinement.

## Counterexample

Session A holds two generation-7 light candidates. Session B submits one of
those entities while claiming a different capability and origin after the
catalog advances to generation 8. A global option lookup could cross sessions
or complete stale authority. P12 must produce zero plans, preserve unrelated
session state, and purge the stale originating continuation.
