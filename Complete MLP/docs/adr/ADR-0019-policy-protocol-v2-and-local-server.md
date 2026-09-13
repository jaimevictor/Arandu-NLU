# ADR-0019: Deny-first policy, protocol v2, and local server

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P15
- Supersedes: ADR-0007 only for the secret-copy claim identified below

## Context

P11 emits complete evidence-bound `ComposedPlan` graphs and P12 adds one-time
bounded continuation. Protocol v1 predates both contracts and serializes only
the simpler `Plan`. P13 must add policy without putting authority in
interpretation, expose complete outcomes without changing v1, and create a
credential-free local server without preempting the P14 adapter.

The selected CPython/OpenSSL TLS 1.3 external-PSK candidate copies a PSK through
an immutable Python object, callback buffers, an OpenSSL session, and derived
traffic-secret storage. Upstream source can cleanse some temporary buffers but
cannot prove that every runtime-created copy is individually locked and
destroyed. One-time pairing display also necessarily creates transient UI
copies. The literal all-copy claim in ADR-0007 is therefore not implementable
with this or another normal managed runtime.

The user authorized a best-available documented workaround and directed the
project to finish rather than refine indefinitely. `USR-018` records the
bounded security compromise without weakening authentication, encryption,
isolation, or disclosure controls.

## Decision

### Policy Boundary

Add a standard-library-only `policy-engine`:

```text
nlu-core + session-engine <- policy-engine
```

The engine owns an immutable generation-tagged table keyed by exact
`(CapabilityId, OperationId)`. A descriptor contains a closed risk class,
permitted graph classes, and one closed disposition: deny, allow without
confirmation, or require confirmation. Duplicate or malformed descriptors are
invalid, and an absent key denies.

Policy evaluates the complete `ComposedPlan`. A denied node, unsupported graph
class, stale generation, contradiction, or `NonExecutable` plan denies the
whole graph and emits no executable subset. `AtomicOnly` denies until P14
provides one reviewed all-or-nothing operation mapping. A policy acceptance is
explicitly not caller authorization or execution authority.

One-time confirmation state uses a bounded deterministic
`Mutex<BTreeMap<SessionId, PendingConfirmation>>`. It stores the exact
canonical plan bytes, all graph capabilities, catalog and policy generations,
closed risk, session, and checked injected logical deadline. It holds at most
64 entries with at most 300,000 logical TTL ticks. Consumption removes the
entry before comparison. Mismatch, replay, expiry, cancellation, rollback,
reload, and construction failure are terminal.

### Protocol v2

Protocol v1 code, schemas, fixtures, limits, decoding, and canonical bytes
remain unchanged for the complete release.

Add a separate strict JSON protocol v2. Its request variants are `interpret`,
`continue`, `confirm`, `cancel`, and `health`. Its responses carry complete
`ComposedPlan` graphs, continuation-bearing clarification, abstention, policy
denial, confirmation required, non-authorizing policy acceptance,
cancellation, bounded health, or a protocol error.

Every DTO is distinct from core types and rejects unknown or duplicate fields,
unknown versions and tags, malformed UTF-8, trailing input, invalid spans and
graphs, and incompatible variants. V2 permits at most 131,072 wire bytes,
16,384 decoded string bytes, depth 32, 4,096 structural items, 20-byte integer
tokens, core collection limits, and eight diagnostics. Diagnostics contain
only closed codes, optional technical node IDs, and fixed numeric limits. They
contain no free text, hostile input echo, credential, residential value,
caller, path, or timestamp.

### Credential-free Server

Add `nlu-server` above the existing interpretation, catalog, session, policy,
and protocol components. Those components never depend on the server.

P13 binds one documented Unix-domain listener. Wyoming serving and Home
Assistant access remain P14 work. Frames use a four-byte big-endian length
checked before allocation. Connections, queued work, workers, frames per
connection, frame time, and request time are bounded. Production server code
has no outbound connect path or outbound-client dependency.

The server receives explicit configuration and an allowlisted environment.
Credential-bearing input fails startup. The server has no pairing, Supervisor
token, caller authorization, or execution DTO.

One immutable `RuntimeSnapshot` contains language, catalog, policy, and
configuration state. A replacement is fully built and validated before an
atomic `Arc` swap. Each request observes one complete snapshot. Reload
invalidates affected sessions and confirmations; failure retains the prior
snapshot. Health is bounded and contains only readiness, supported protocol
versions, and non-sensitive generations.

### Home Assistant And Wyoming Compatibility

P13 verifies the exact admitted Home Assistant 2026.8.3 and Wyoming 1.10
contract sources before transport behavior freezes. Wyoming loses complete
clarification, ordered execution, caller context, or explicit continuation
unless executable evidence proves otherwise. Every flow losing one of those
properties uses the companion path or abstains. Wyoming remains a compatibility
reference, not a runtime dependency or authority in P13.

### Companion Transport And Secret Memory

P13 conditionally selects CPython 3.14 `ssl` TLS 1.3 external PSK backed by an
admitted OpenSSL 3.x runtime. Both network peers use fixed roles, TLS 1.3 only,
PSK-DHE, fixed identity and ALPN, fresh contexts, and no certificate fallback,
TLS 1.2, tickets, resumption, or early data. P14 retains pairing and channel
implementation.

Persistent active pairing state and private session keys live only in two
dedicated peer processes: the add-on adapter and a companion transport helper
owned by the Home Assistant integration. Each peer locks its complete address
space before receiving a credential and fails startup or pairing if that lock
cannot be established. The helper has no Home Assistant execution authority;
the integration still executes caller-authorized operations inside Home
Assistant over an inherited bounded local channel.

One-time provisioning representations may traverse bounded Home Assistant and
add-on ingress buffers because display and submission cannot avoid managed
runtime copies. Those copies are never retained as active state, are released
and overwritten where the runtime permits, and are excluded from files,
backups, swap, core dumps, command lines, environment, logs, diagnostics,
metrics, and telemetry. The project reports that immutable managed-runtime
copies cannot be proven zeroized immediately after release.

This paragraph supersedes only ADR-0007's claim that every transient copy can
be proven individually locked and destroyed. All other ADR-0007 pairing,
authentication, revocation, and privacy requirements remain in force.

## Acceptance

P13 acceptance requires:

- all 28 directly owned requirements passing on one immutable candidate;
- exhaustive whole-graph policy and confirmation substitution tests;
- complete v2 outcome round trips and retained exact v1 bytes;
- hostile protocol and framing limits, fuzz, and exhaustion checks;
- atomic reload schedules, concurrent confirmation consumption, socket
  inspection, outbound-denial, credential canaries, and bounded health tests;
- executable exact-source Home Assistant/Wyoming compatibility evidence;
- admitted exact CPython/OpenSSL source, license, provenance, build,
  architecture, advisory, and runtime evidence, including independent source
  reviews;
- a transport probe showing required negotiation and rejection behavior,
  without claiming P14 end-to-end pairing completion;
- focused and full locked/offline tests, builds, formatting, strict clippy,
  inherited gates, privacy scans, and exact-subject reproducibility; and
- seven independent candidate reviewers passing with no open P0 through P2.

The selected tuple is convergence pass 1 of at most 3. Freeze the first
minimum immediately. Later passes and candidate rounds are blocker-only.

## Consequences

- Interpretation remains separate from policy and execution.
- Protocol v1 remains supported while v2 can carry complete semantics.
- The P13 server is locally reachable but credential-free and outbound-free.
- P14 receives explicit non-authorizing policy results and complete plans.
- Process-wide locking contains persistent transport secrets, while the
  unavoidable bounded provisioning-copy residual risk remains explicit.
- The companion transport helper adds one packaged process but is not an
  external supervisor and has no Home Assistant authority.

## Alternatives

1. Extend protocol v1. Rejected because complete graph and continuation fields
   are incompatible with its frozen strict schema.
2. Put policy in the NLU core or server handlers. Rejected because it couples
   interpretation to mutable authority.
3. Use Python Noise plus a separate Rust Noise implementation. Rejected
   because the Python package is old, explicitly unaudited, and creates a
   larger cross-language source and interoperability surface.
4. Use certificate mTLS. Rejected because file-oriented stdlib key loading,
   certificate lifecycle, and pairing-key proof add state without eliminating
   managed-runtime secret copies.
5. Claim every transient secret copy is locked and zeroized. Rejected because
   source inspection disproves the claim.

## Rollback

Disable protocol-v2 execution and companion action routing while retaining
strict v1 recognition. A failed reload retains the previous snapshot. If the
transport portfolio fails admission, remove its source records and derived
code before selecting the next pass. Never fall back to plaintext, custom
cryptography, persistent credentials, or guessed authorization.
