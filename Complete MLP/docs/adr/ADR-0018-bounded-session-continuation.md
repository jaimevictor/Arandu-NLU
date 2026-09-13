# ADR-0018: Bounded session continuation

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P12-P14

## Context

P10 can return bounded entity candidates, and P11 can build a complete
evidence-bound plan. The P11 clarification outcome does not retain the exact
missing endpoint, originating capability, or already validated bindings.
Using a later entity result by global option ID could therefore cross
sessions, fill the wrong slot, accept a stale catalog, or complete twice.

P12 must add short-lived context without general personal memory, ambient
time, persistence, policy, execution authority, or a protocol-v1 change.

## Decision

### Resumable Composition

Extend `plan-engine` with a separate resumable route. Existing `compose`
behavior remains available and unchanged.

A non-cloneable `PendingEntityComposition` retains the original source-bound
evidence, graph shape, resolved bindings, exactly one unresolved node/slot
endpoint, capability, catalog generation, and canonical candidate
`EntityRef` values. It retains no catalog snapshot.

Completion consumes the pending value. It accepts only one exact stored
referent at the recorded generation, fills only the recorded endpoint, and
rebuilds the complete plan through P11 validation. Follow-up text cannot
become evidence in the retained graph, and an unresolved tie or unknown
referent produces no plan.

### Session Store

Add `session-engine`, depending only on `nlu-core` and `plan-engine`. It uses
one `Mutex`-protected deterministic state with a
`BTreeMap<SessionId, PendingSession>`.

`SessionId` is an injected opaque 32-byte value. Each entry binds one session
to one typed invocation origin, capability, generation, endpoint, pending
composition, bounded referent set, and checked logical deadline.

The fixed bounds are:

- 64 live sessions;
- one pending continuation per session;
- 16 referents per continuation; and
- 300,000 configured logical ticks maximum TTL.

Zero TTL, deadline overflow, duplicate session insertion, and every one-over
limit reject the complete update without eviction or truncation. A session is
valid strictly before its deadline and expires exactly at equality. Logical
time is injected; rollback purges all pending state and fails closed.

All state transitions linearize under one lock. Completion removes the pending
value before constructing the final plan, establishing at-most-once
consumption. Completion, invalid selection, unresolved tie, cancellation,
expiry, and generation change are terminal for the addressed state. A
mismatched session never consumes another session.

### Privacy And Authority

Session state is sensitive residential data. It remains in process memory,
has no persistence or serialization API, and drops on every terminal
transition, restart, or store destruction. Errors expose closed codes and
debug output exposes only type and bounded counts.

The component reads no wall clock, entropy, locale, environment, filesystem,
network, or global mutable state. Session IDs, origins, deadlines, and logical
time do not enter plan values, canonical plan bytes, or protocol v1.

Session state carries no authorization, confirmation, risk classification,
credential, caller identity, pairing epoch, service name, payload, callback,
execution result, or rendering instruction. P13/P14 add caller and pairing
bindings around this contract and must use the companion or abstain whenever
Wyoming would lose continuation semantics.

## Acceptance

Acceptance requires:

- `GLB-SESSION-001..003`, `ARC-DIALOG-001`, and
  `P12-SES-001..015` passing;
- boundary, substitution, replay, cancellation, expiry, stale-generation,
  unresolved-tie, privacy, restart, and source-release tests;
- deterministic schedule enumeration and a real concurrent at-most-once test;
- resumed and directly resolved plans producing identical P11 canonical bytes;
- unchanged protocol-v1 fixtures and inherited P10/P11 behavior;
- focused and full locked tests/builds, strict clippy and formatting,
  source/license/privacy gates, and exact-commit reproduction; and
- all mandatory reviewers passing one immutable candidate with no open P0-P2.

The selected tuple is convergence pass 1 of at most 3. P12 freezes the first
minimum candidate immediately. Remaining passes and candidate rounds are
blocker-only and are not refinement entitlement.

## Consequences

- Clarification can be resumed without reinterpreting follow-up text.
- Stored context is narrowly typed, bounded, generation-bound, and one-time.
- P12 does not preempt caller authorization, pairing, transport, or execution.
- Protocol v1 remains unchanged.
- P14 still owns packaged restart and filesystem canary evidence for
  `P12-SES-016`; P13/P14 own compatibility and caller/epoch bindings.

## Alternatives

1. Re-run the original utterance after a follow-up. Rejected because it can
   resolve against different evidence or catalog state.
2. Store only a global option ID. Rejected because it omits session,
   capability, endpoint, generation, and origin bindings.
3. Store the complete catalog snapshot. Rejected because retained residential
   state is unnecessary; typed referents and generation are sufficient.
4. Add continuation fields to protocol v1. Rejected because v1 is frozen and
   strict; P13 owns the next transport contract.
5. Persist sessions for restart recovery. Rejected by the memory-only privacy
   boundary.

## Rollback

Before acceptance, remove `session-engine`, the resumable `plan-engine` route,
and this ADR, returning to the P11 closeout tree. After acceptance, disable
continuation, purge all state, and fall back to fresh clarification or
abstention. A changed contract requires a superseding ADR.
