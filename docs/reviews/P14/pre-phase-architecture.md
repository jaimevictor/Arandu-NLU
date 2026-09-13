# P14 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a05ac3-f43a-7e83-affe-ff6f6be5a856`
- Input commit: `371ba75966c435e4d2026a24e427b8f35da79115`
- Input tree: `6291bd5d349c79b9ac62d5b4ab324ad29628b61f`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SELECTED`

## Selected Topology

P14 adds one Rust adapter boundary and one Python Home Assistant companion:

```text
Home Assistant/Supervisor API
          |
    add-on adapter ---------- authenticated companion channel
          |                                  |
 bounded Unix IPC                    custom integration
          |                                  |
      nlu-server                    typed HA internal APIs
```

The add-on adapter is the container entry process and the only project process
that receives the Supervisor token or initiates Home Assistant API traffic.
The existing `nlu-server` remains credential-free and cannot execute. The
custom integration is the only project component that authorizes and executes
operations inside Home Assistant.

The adapter and server use a dedicated Unix-socket generation directory,
socket mode `0660`, distinct unprivileged identities, one shared IPC group,
and kernel peer-credential checks. Every frame is versioned, bounded, closed,
and typed. No raw Home Assistant service name or arbitrary payload crosses the
boundary.

## Typed Bindings

Every companion request binds:

- protocol version and pairing epoch;
- fixed direction, connection nonce, and monotonic sequence;
- stable operation ID and node-attempt ID;
- canonical plan digest;
- session and capability;
- catalog generation;
- Home Assistant context ID and caller ID; and
- the exact typed operation and bounded target set.

The companion independently revalidates those fields, the current user,
active status, current target expansion, per-target permission, policy,
catalog generation, capability contract, timeout, and prior node results
immediately before each effect. A mismatch produces no dispatch.

## Pairing And Channel

Pairing is an explicit local config-flow and add-on-ingress transaction.
Persistent credentials and private session keys exist only in dedicated
process-wide-locked peer processes. Pairing state is never serialized. A
restart, peer removal, config-entry removal, or epoch change invalidates all
connections, sessions, confirmations, and operation identities and requires
local re-pairing.

Only the selected Noise revision 34 and Snow 0.10.0 P13 source projection may
be admitted. Product enablement requires native Linux amd64 and aarch64 builds
from a kernel-enforced read-only source snapshot and proof that rejected source
is unreachable.

## Execution And Idempotency

The companion owns a bounded in-memory ledger keyed by
`(epoch, operation_id, node_attempt_id)`. Entries are `Reserved`, `InFlight`,
`Completed`, `Indeterminate`, or `Expired`. Reservation precedes every effect.
A completed duplicate returns its typed cached result; an in-flight,
cancelled, or timed-out duplicate never redispatches blindly. Unknown or
expired old identities fail closed.

Ordered partial-safe graphs execute sequentially and revalidate before each
node. A failure or indeterminate result stops the graph. Conflicting,
contradictory, transactional, or unsafe-partial graphs abstain before any
effect unless one reviewed whole-graph operation proves zero-or-all behavior.

The minimum `P14-CONTRACT-008` capability is a read-only bundled state
snapshot. One companion event-loop operation validates every requested entity,
captures all requested states, and returns one typed result only after the
complete bundle succeeds. Missing, unauthorized, stale, or malformed input
rejects the whole request. The operation has no external effect, so every
failure point is necessarily before a first effect and partial execution is
impossible.

## Wyoming And Rendering

Wyoming 1.10 advertises only an installed PT-BR `IntentProgram` and maps
abstention to `NotRecognized`. It never advertises `HandleProgram`. Its initial
safe set is restricted to reviewed, single-target, non-user-scoped read-only
handlers. Expanding, sensitive, ordered, dependent, conflicting, caller-bound,
or continuation-bearing work uses the companion or abstains.

A separate deterministic renderer consumes interpretation and execution
outcomes. It never changes policy or execution and never combines a predicted
plan with an execution result that was not bound to that plan.

## Verification And Packaging

The minimum gate includes deterministic mock schedules, protocol mutations,
privacy canaries, process and peer inspection on Linux, pinned Home Assistant
2026.8.3, one exact latest-stable Home Assistant identity, Wyoming 1.10,
native amd64/aarch64 read-only-source builds, and install/restart/re-pair
coverage. Every executable and package is admitted before use.

Candidate round 1 freezes when this minimum passes. P14 allows at most three
substantive frozen candidates; later candidates are blocker-only.

## USR-043 Final Remediation Addendum

The selected final-pass architecture adds no product component. It closes the
frozen blockers inside the existing adapter/companion boundary by:

- retaining a bounded, non-evicting canonical-submission registry for each
  pairing epoch and issuing sequential operation IDs with explicit retries;
- retaining companion operation high-water state so retired IDs cannot return
  as fresh work;
- tracking and reconciling evidence per exact operation/effect pair without
  allocating normal operation capacity to probes;
- sharing one exception-catching monotonic logical-time latch across session
  and ledger users;
- revision-binding every helper exchange across awaits and erasing retired
  epoch state;
- persisting restart barriers fail closed; and
- proving helper child exit before deterministic private-endpoint cleanup.

This is the sole integrated approach for pass `1 of 1`. It preserves the
existing protocol, process topology, dependency set, P13 bytes, and P15
transfers.
