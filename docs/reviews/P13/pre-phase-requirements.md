# P13 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `01a04dea-ef53-79a2-b84c-5a6cf313b2ab`
- Input commit: `1b28fd9ef334540539118b17250a0f46b43b0ed1`
- Input tree: `c82dfe4a51b660ada0784cf9685117ccc4c7bb85`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, held-out data, prohibited sources,
  or closed-engine material
- Result: `CONVERGENCE_PASS_1_SCOPE_SELECTED`

## Mandatory Closure

P13 closes exactly these 28 requirements:

- `GLB-SEC-001`;
- `ARC-LANG-002`, `ARC-POLICY-001`, `ARC-PROTO-001`, and
  `ARC-SERVER-001`;
- `P10-HA-024`;
- `P12-COMPAT-001..005`;
- `P13-POL-001..004`;
- `P13-PROTO-001..006`;
- `P13-SRV-001..006`; and
- `P13-GATE-001`.

Policy uses a closed risk and capability matrix, denies unknown actions, binds
one-time confirmation to the exact canonical plan, session, and capability,
and never emits an executable subset after denial.

Protocol v1 remains byte-compatible and decodable. Protocol v2 preserves the
complete `ComposedPlan`, every complete typed outcome, strict bounded
diagnostics, canonical bytes, and hostile-input limits. It carries no
credential, caller-supplied authority, raw service name, or arbitrary payload.

The server exposes only documented local listeners, has no outbound client,
receives an explicit credential-free environment, retains no credential type
or state, atomically exchanges immutable runtime snapshots, and exposes only
bounded residential-data-free health.

## Minimum Acceptance

The first minimally acceptable candidate must:

- satisfy all 28 owned rows with reproducible positive and negative tests;
- preserve the exact protocol-v1 schemas, fixtures, decode behavior, and
  canonical bytes while introducing incompatible complete outcomes only in
  protocol v2;
- round-trip every `ComposedPlan` field and every typed v2 outcome while
  rejecting unknown fields, versions, tags, invalid graphs, excess bytes,
  strings, nesting, numbers, and structural items;
- exhaust the closed policy matrix, deny unknown capability/operation pairs,
  consume confirmation once, reject every bound-field substitution, and
  return no executable subset for a denied graph;
- prove immutable snapshot reload is atomic under deterministic schedules and
  real concurrency;
- prove the server has only its documented local listeners, no outbound
  client API or dependency, no credential-bearing environment/DTO/memory
  state, and bounded non-sensitive health;
- reproduce the exact Home Assistant 2026.8.3 and Wyoming 1.10 compatibility
  contract before transport selection is frozen;
- select and admit a FOSS companion transport portfolio without weakening
  pairing, authentication, encryption, source, license, or memory-handling
  requirements;
- pass focused tests, strict clippy, locked/offline workspace tests and
  builds, retained hostile protocol fuzz/exhaustion checks, source/privacy
  scans, inherited gates, and exact-subject reproducibility;
- receive `PASS` from all mandatory independent reviewers on one immutable
  subject with no open P0 through P2 finding; and
- checkpoint immediately after the first passing minimum without optional
  refinement.

## Deferred Shared Work

P13 tests its component contribution but does not mark P14/P15 end-to-end rows
satisfied. `P12-SES-016..020`, `P12-COMPAT-006`,
`P13-AUTH-001..012`, `P13-PAIR-001..012`, `P13-CHAN-001..007`,
`P13-BIND-001`, and the adapter, packaging, release, and complete shared
privacy/security rows remain pending for their assigned phases.

## Source And Compatibility Prerequisites

The candidate CPython/OpenSSL TLS 1.3 external-PSK portfolio is not admitted
by a successful local handshake alone. Admission must identify exact source,
license, rightsholder, archive, executable, linkage, build configuration,
provider, cipher, advisory, Home Assistant runtime, and transitive-closure
evidence, with independent discovery, license, provenance, quality/security,
and defensive-adversarial reviews.

The implementation evidence must establish TLS 1.3 only, mutual PSK
authentication, forward-secret PSK-DHE, bounded handshakes, no certificate or
plaintext fallback, no TLS 1.2, ticket, resumption, or early data, and
fail-closed handling of absent, wrong, stale, pending, and competing epochs.
P14 retains end-to-end companion execution proof.

The accepted secret-memory contract must be implementable for every pairing
credential and private-session-key copy in both peers. If a selected runtime
cannot establish that property, the portfolio is rejected or a newer explicit
user-authorized structural decision must document a feasible fail-closed
replacement; the candidate may not silently claim locked memory.

The exact Home Assistant and Wyoming references must prove whether the
Wyoming bridge preserves complete clarification, ordering, caller context, and
an explicit continuation flag. Loss of any property requires the companion
path or abstention. Wyoming remains a reference unless separately admitted as
a runtime dependency.

## Bounded Convergence

One convergence pass is one integrated and dispositioned source portfolio,
transport selection, policy model, protocol-version plan, server boundary,
and test portfolio. This is pass 1 of at most 3. P13 permits at most three
substantive frozen candidate rounds; rounds 2 and 3 are blocker-only.

If a transport portfolio fails admission, remove its quarantined bytes,
ledger entries, dependency edges, and derived code before selecting the next
pass. Never fall back to plaintext or custom cryptography. After three failed
passes or three failed candidate rounds with a P0 through P2 blocker, stop for
explicit scope adjudication. Rollback retains the P12 checkpoint, protocol v1,
and disabled companion execution.

## Counterexample

An ordered two-node plan sent through Wyoming can lose caller context,
continuation state, and ordering during concurrent dispatch. Separately,
transport authentication alone does not authorize a request whose session,
capability, plan digest, or caller was substituted. The first case must use
the companion or abstain; the second must be rejected before authorization or
effect.

Read-only checks reproduced the clean baseline, `tools/validate-p12`, 22
protocol tests, and 15 session tests.
