# P13 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04df6-6ed5-7c23-a2fd-864d622d1bcd`
- Input commit: `1b28fd9ef334540539118b17250a0f46b43b0ed1`
- Input tree: `c82dfe4a51b660ada0784cf9685117ccc4c7bb85`
- Mode: read-only independent primary-evidence inspection
- Independence: repository baseline only; no edits, network, siblings,
  held-out data, prohibited sources, or closed-engine material
- Result: `CONVERGENCE_PASS_1_SELECTED_TRANSPORT_CONDITIONAL`

## Selected Components

Add two production components:

```text
nlu-core + session-engine <- policy-engine
nlu-core + lang-ptbr + intent-engine + ha-catalog + plan-engine
  + session-engine + policy-engine + protocol <- nlu-server
```

`protocol` remains DTO-only and depends on `nlu-core`, Serde, and JSON. Core,
interpretation, session, and policy never depend on protocol or server. This
preserves ADR-0003, `docs/security/TRUST-BOUNDARIES.md`, and `GLB-SEC-001`.

## Policy

`policy-engine` owns an immutable generation-tagged table keyed by exact
`(CapabilityId, OperationId)`. Every descriptor contains a closed risk class,
typed slot schema, permitted graph classes, and one of `Deny`,
`AllowWithoutConfirmation`, or `RequireConfirmation`. Construction rejects
duplicate, malformed, incomplete, or unknown descriptors.

The initial table explicitly dispositions every operation key in
`crates/plan-engine/src/table.rs`. Read-only queries may pass policy without
confirmation. State-changing and sensitive operations require confirmation or
are explicitly denied. Missing keys deny. `NonExecutable` always denies;
`AtomicOnly` denies until P14 provides a reviewed atomic operation mapping.

Policy evaluates every node in one complete `ComposedPlan`. One denied node
denies the graph; no subset or per-node executable result is emitted. A policy
pass is explicitly not caller authorization or execution authority.

## Confirmation State

Use one bounded `Mutex<BTreeMap<SessionId, PendingConfirmation>>`, following
`crates/session-engine/src/store.rs`:

- at most 64 entries and one entry per session;
- at most 300,000 injected logical TTL ticks;
- exact canonical plan bytes, every capability, catalog generation, policy
  generation, risk, and session stored;
- no project-authored plan hash in P13;
- removal before validation establishes terminal one-time consumption;
- mismatch, replay, expiry, cancellation, rollback, or reload is terminal; and
- logical-time rollback purges all confirmations.

A confirmation approves only the policy decision for that exact graph. P14
must still authenticate the caller, revalidate the plan, and authorize every
effect.

## Protocol v2

Keep `crates/protocol/src/v1.rs`, its fixtures, and both v1 schemas
byte-compatible. Add `v2.rs` and separate v2 schemas.

V2 request variants are closed: `interpret`, `continue`, `confirm`, `cancel`,
and `health`. They accept no caller identity, permission, risk, raw service
name, arbitrary payload, or execution authority.

Closed response variants are:

- complete `ComposedPlan`, including all clauses, evidence, relations,
  independence, shares, class, and generation;
- entity clarification with explicit continuation state and bounded typed
  referents;
- abstention;
- policy denial;
- confirmation required;
- policy accepted, explicitly non-authorizing;
- cancellation;
- health; and
- protocol error.

V2 allows at most 131,072 wire bytes, 16,384 decoded string bytes, depth 32,
4,096 structural items, 20-byte integer tokens, 64 nodes, 256
relations/shares/pairs, 32 slots per node, 64 evidence spans per collection,
16 clarification options, and eight diagnostics. Diagnostics contain only
closed codes, optional technical node IDs, and fixed numeric limits. They
contain no free text, hostile-input echo, credential, utterance, entity,
caller, path, or timestamp. `preflight.rs` becomes parameterized while
retaining exact v1 limits.

## Server And Reload

`nlu-server` binds one documented Unix-domain listener only. Wyoming serving
remains P14 work. Frames use a four-byte big-endian length checked before
allocation. Fixed workers, bounded queues, per-frame timeouts, and bounded
frames per connection limit stalled clients. Production code contains no
connect path or outbound-client dependency.

The server receives configuration explicitly and starts under an environment
allowlist. A credential-bearing input causes startup rejection. It never holds
a Supervisor token or companion pairing secret.

`RuntimeSnapshot` contains immutable language, catalog, policy, and
configuration state. A replacement is fully built and validated before the
store write lock is acquired. Requests retain one snapshot read guard for
their complete state transition. Reload invalidates sessions and
confirmations, then swaps one `Arc<RuntimeSnapshot>` under the write lock. A
failed reload retains the prior snapshot. Health is capped and exposes only
readiness, supported protocol versions, and non-sensitive generation
information.

## Home Assistant And Wyoming Proof

A test-only harness verifies the exact Home Assistant and Wyoming commits and
path hashes in `docs/clean-room/MATERIALS.yaml`, then executes contract cases
for complete clarification, ordered multi-node execution, Home Assistant
caller context, and explicit continuation.

Loss of any property records the companion path as mandatory. Wyoming remains
an open-reference compatibility surface, not a runtime dependency or
execution authority.

## Transport Disposition

Conditionally select CPython `ssl` TLS 1.3 external PSK backed by OpenSSL for
the adapter-to-companion channel, with Python peers on both sides. Require TLS
1.3 only, PSK-DHE, fixed roles, identity and ALPN, and no certificate fallback,
TLS 1.2, tickets, resumption, or early data. P13 records exact source, license,
build, advisory, architecture, and Home Assistant runtime evidence; P14 owns
pairing and channel implementation.

Direct source inspection identifies a P1 admission blocker: CPython PSK
callbacks expose immutable Python secret objects and OpenSSL creates
additional stack, session, and traffic-secret copies. This does not establish
the locked-memory requirement in ADR-0007. The portfolio must not be
unconditionally admitted under that requirement. It must either satisfy a
newer explicit user-authorized feasible secret-memory contract or be rejected
before P13 candidate freeze. Plaintext and custom cryptography remain
prohibited.

## Verification

Tests cover exhaustive policy cells, whole-graph denial, every confirmation
field substitution, concurrent double consumption, reload races, all v2
variants, unchanged v1 fixture hashes, exact and one-over limits, duplicate
and escaped-duplicate fields, malformed UTF-8 and framing, retained hostile
fuzz/exhaustion, socket inspection, outbound denial, environment and memory
canaries, mixed-generation races, bounded health, exact Home
Assistant/Wyoming compatibility, and transport source reviews.

Counterexample: session S confirms plan A, then a catalog or policy reload
introduces plan B. A store keyed only by S could authorize B. Exact plan bytes,
all capabilities, both generations, terminal consumption, and reload
invalidation must instead produce denial.

## Bounded Completion

This integrated architecture and source portfolio is convergence pass 1 of at
most 3. P13 candidate round 1 freezes only after all 28 directly owned rows
pass, transport evidence is dispositioned, seven mandatory reviewers pass one
immutable baseline, and no P0 through P2 remains. Freeze the first minimum
immediately. P14 retains execution, caller authorization, pairing,
authenticated-channel operation, and Wyoming serving.
