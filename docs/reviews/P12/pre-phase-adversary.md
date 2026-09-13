# P12 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04bd7-662f-7eb3-8cc0-c1990782fa43`
- Input commit: `e1146f920a8997ff9985bff494e44813817426c9`
- Input tree: `de3042a725e7589d4185be86f0f2a14fa183e205`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `THREAT_PLAN_SELECTED`

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P12-A01` | A result substitutes session, origin, capability, node, slot, generation, or referent. Bind and compare every field before consuming a plan. |
| P0 | `P12-A02` | Session state carries authorization, confirmation, risk, raw service, payload, credential, callback, or execution override. Exclude those types and dependencies entirely. |
| P1 | `P12-A03` | Sequential or simultaneous replay completes twice. Atomically remove one-time state before graph completion. |
| P1 | `P12-A04` | A stale generation or retained snapshot silently remaps an entity. Purge and return no plan; never re-resolve implicitly. |
| P1 | `P12-A05` | Deadline overflow, exact-boundary use, or clock reversal extends state. Use checked arithmetic, expire at equality, and purge on rollback. |
| P1 | `P12-A06` | Candidate order or an unresolved tie selects index zero. Require one exact stored typed referent and treat unresolved input as terminal non-completion. |
| P1 | `P12-A07` | Take, cancel, expiry, or generation invalidation race. Linearize all state transitions under one lock and enumerate schedules. |
| P1 | `P12-A08` | Restart, diagnostics, or delayed drop persists utterances or residential state. Provide no persistence or serialization path and test release on every terminal transition. |
| P2 | `P12-A09` | Limits truncate, evict, wrap aggregate arithmetic, or partially update. Test exact and one-over limits and reject updates atomically. |
| P2 | `P12-A10` | Session identifiers encode user data, time, or counters, or a collision overwrites state. Accept only injected fixed-size opaque bytes and reject collisions. |
| P2 | `P12-A11` | Follow-up text is spliced into source-bound P11 evidence. Resume only through the sealed pending endpoint and original evidence. |
| P3 | `P12-A12` | Error and debug differences reveal session or residential values. Return closed outcomes and count-only diagnostics. |

## Required Schedules

Enumerate both orderings of:

1. take versus take;
2. take at the exact deadline versus expiry;
3. take versus cancellation;
4. take versus catalog-generation invalidation;
5. cancellation versus generation invalidation; and
6. clock rollback versus every state-changing operation.

Every replay of the same explicit schedule must produce identical typed
results and final structural state. A synchronized real-thread test must also
show at most one completed plan.

## Required Mutations

Mutate session, origin, capability, node, slot, generation, and referent one at
a time. Exercise zero, exact, and one-over TTL/session/referent limits; deadline
overflow; duplicate insertion; missing sessions; cancellation replay; stale
catalogs; foreign referents; reordered candidates; unresolved ties; and
protocol-v1 injection attempts.

Privacy tests use distinct technical canaries for request, entity, session,
origin, and option values and inspect `Debug`, `Display`, errors, diagnostics,
panic output, and filesystem changes.

## Fail-closed Contract

Any mismatch, ambiguity, expiry, rollback, stale generation, replay, duplicate,
poisoned lock, internal construction error, or limit breach produces no plan.
No path chooses a candidate by position. A failed command against one session
cannot consume another session's state.

## Bounded Stop

One convergence pass is one selected and dispositioned continuation schema,
resume boundary, time model, store, schedule model, and mutation portfolio.
P12 has at most three passes and three frozen candidate rounds. Freeze the
first passing minimum; after the third blocker, stop for explicit scope
adjudication rather than adding authority, persistence, or heuristics.

## Counterexample

At generation 7, session A contains one light option. Session B submits that
entity with a forged unlock capability and origin while two retries race at
the exact TTL boundary. A global option map or remove-after-build design can
cross sessions, complete stale authority, or emit two plans. The selected
store must emit zero plans at the deadline and leave unrelated state intact.
