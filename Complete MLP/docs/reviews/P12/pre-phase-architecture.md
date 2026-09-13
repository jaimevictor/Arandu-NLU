# P12 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04bd7-5a1c-7082-a3ec-771707530e11`
- Input commit: `e1146f920a8997ff9985bff494e44813817426c9`
- Input tree: `de3042a725e7589d4185be86f0f2a14fa183e205`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SELECTED`

## Selected Boundary

Add a standard-library-only `session-engine`:

```text
nlu-core + plan-engine <- session-engine
```

`plan-engine` gains a separate resumable composition route while its existing
`compose` contract remains unchanged. A non-cloneable
`PendingEntityComposition` retains one exact unresolved node/slot endpoint,
the originating capability and generation, canonical candidate `EntityRef`
values, source-bound evidence, and all other validated bindings.

Completion consumes the pending value, accepts exactly one stored referent,
fills only the recorded endpoint, and rebuilds the complete graph through the
existing P11 constructors and invariants. It does not splice follow-up text
or evidence into the original graph.

## Session State

`SessionStore` owns one `Mutex<State>`. `State` contains a
`BTreeMap<SessionId, PendingSession>` and the last observed logical time.
Each state transition linearizes under that lock. The pending composition is
removed before terminal completion, so a concurrent retry cannot receive a
cached plan or cause a second completion.

The closed state contains only:

- one injected opaque 32-byte `SessionId`;
- one typed `InvocationId` origin;
- one capability, catalog generation, and node/slot endpoint;
- one pending composition;
- at most 16 typed `EntityRef` referents; and
- one checked logical deadline.

There are at most 64 live sessions, one pending continuation per session, and
a maximum configured TTL of 300,000 logical ticks. Zero TTL and
`created + ttl` overflow are rejected. State is valid strictly before its
deadline and expires exactly at the deadline. Logical-time rollback purges all
pending state and fails closed.

Insertion collisions reject the complete update and never replace or evict
state. Completion, invalid selection, unresolved tie, cancellation, expiry,
and stale catalog generation are terminal for the addressed continuation.
Mismatched sessions never consume another session's state.

## Determinism And Privacy

IDs and time are explicit injected inputs. No entropy, wall clock, locale,
environment, filesystem, network, unordered collection, persistence, Serde,
logging, metric, policy, or execution dependency is permitted.

Plans and protocol-v1 bytes contain no session ID, origin, deadline, or
logical time. Errors expose closed codes; `Debug` exposes only type and bounded
counts. Pending source and referents drop on every terminal transition, store
destruction, or restart.

## Verification

Tests cover 64/65 sessions, 16/17 referents, exact TTL boundaries, overflow,
rollback, duplicate insertion, replay, cross-session completion, forged
origin/capability/endpoint/generation, unknown referents, unresolved ties,
cancellation, stale-generation purge, restart-empty behavior, source
retention release, privacy canaries, deterministic command schedules, and a
real-thread atomic double-take.

P11 canonical bytes from resumed plans must equal bytes from the same fully
resolved explicit inputs. Protocol v1 fixtures and the existing non-resumable
P11 route remain unchanged.

## Ownership And Deferral

`plan-engine` owns pending composition and exact-slot graph completion.
`session-engine` owns opaque sessions, TTL, limits, bindings, isolation,
cancellation, purge, and concurrency. `nlu-core` retains typed identifiers,
logical time, referents, and graph invariants.

P12 adds no transport, caller identity, authorization, confirmation,
execution, rendering, pairing, catalog acquisition, or persistence API.
P13/P14 bind caller and pairing epochs around this continuation contract and
select the companion whenever transport would lose its semantics.

## Bounded Completion

This integrated contract and test portfolio is convergence pass 1 of at most
3. Freeze candidate round 1 immediately when the minimum passes. Remaining
passes and candidate rounds are available only for reproduced blockers.
