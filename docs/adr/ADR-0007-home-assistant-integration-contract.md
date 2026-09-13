# ADR-0007: Home Assistant integration contract

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P10, P13-P15

## Context

An installable add-on does not by itself become an Assist conversation agent.
The integration needs a current, open protocol, a catalog synchronization path,
clear credential ownership, and compatibility tests.

Home Assistant Core 2026.8.3 is Apache-2.0 at tag commit
`759e4658f40b3ccb671d418b8a0ed95224bf4561`. Its Wyoming integration depends on
Wyoming 1.10.0 and creates a conversation entity for an advertised
`IntentProgram`. It sends transcript text plus conversation, device, and
satellite metadata over local TCP, accepts one `Intent` or an
`IntentsStart`/`Intent`/`IntentsStop` stream, and invokes Home Assistant's
registered intent handlers.

The source contract has three safety constraints that the initial design must
not hide:

- `ConversationInput` has a Home Assistant `Context` with `user_id`, but the
  Wyoming transcript metadata omits it and the bridge invokes
  `intent.async_handle` without that caller context;
- the bridge dispatches a multi-intent stream concurrently;
- one Home Assistant intent handler can fan a target match out to several
  concurrent service calls, report partial success, and let a service task keep
  running after its short validation timeout.

The Wyoming protocol implementation is MIT-licensed. These observations are
limited to the exact open-source paths and hashes recorded in the material
ledger.

Official add-ons advertise `discovery: [wyoming]`; add-ons that need the Home
Assistant catalog use `homeassistant_api: true` and the local Supervisor
WebSocket endpoint.

## Decision

The Home Assistant app/add-on is the primary distribution. The release also
contains a minimal open-source companion conversation integration. Together
they expose:

1. a bounded local Wyoming 1.10-compatible intent-recognition service
   advertising only an installed PT-BR `IntentProgram`;
2. the project's versioned local protocol for full typed outcomes and
   diagnostics;
3. an authenticated companion channel that preserves Home Assistant caller
   context and supports clarification plus controlled execution.

It does not advertise a Wyoming `HandleProgram`; Home Assistant remains
responsible for intent execution. A recognized plan maps to a Wyoming intent
event only after adapter revalidation and only when a pinned handler-contract
allowlist proves that every node is non-sensitive, non-user-scoped,
single-target, and safe under the handler's actual timeout and partial-success
semantics. Area, floor, group, wildcard, or otherwise expanding targets are not
single-target. In practice, read-only handlers form the initial Wyoming-safe
subset. Everything else uses the companion or abstains. Abstention maps to
`NotRecognized`. No raw Home Assistant service name or unvalidated payload
crosses either boundary.

Home Assistant 2026.8.3 dispatches a Wyoming multi-intent stream concurrently.
Therefore that stream is permitted only when every node independently passes
the Wyoming-safe handler allowlist, the graph proves all nodes independent and
unordered, and policy marks partial completion safe. Ordered, dependent,
multi-target, caller-authorized, sensitive, conflicting, transactional, or
unsafe-partial graphs must not use Wyoming execution. They use the companion
integration only when policy proves partial completion safe. Its sequential
typed path revalidates each next node against prior results and stops at the
first failure or indeterminate result.

A transactional or unsafe-partial graph is rejected before its first external
effect unless one reviewed capability maps the entire graph to one Home
Assistant operation with a pinned all-or-nothing contract. Sequential stopping,
best-effort rollback, and compensation do not establish atomicity. Conflicting
or contradictory graphs always abstain. If the required atomic capability is
absent, stale, or unavailable, the result is abstention rather than partial
execution.

The companion receives `ConversationInput.context` inside Home Assistant and
never accepts caller identity from an untrusted client. It authenticates its
local channel to the add-on adapter, binds plan, session, capability, catalog
generation, context ID, and caller ID, and executes the final typed operation
inside Home Assistant with the original `Context`. Cross-user continuation,
missing context, context substitution, or a result from another capability
fails closed.

Caller attribution is not authorization. Immediately before every external
operation, the companion resolves `Context.user_id` through the current Home
Assistant auth manager, requires an existing active user, expands the exact
target set, and checks the pinned operation-specific permission predicate for
every target. Entity operations require current `POLICY_CONTROL`; admin-only
operations require the current admin predicate; a capability with no complete
pinned permission mapping is not executable. Authorization is repeated after
every prior graph result, so revocation or target expansion between nodes stops
before the next effect. System or missing contexts are denied unless a
separately reviewed capability explicitly permits that exact HA-originated
context.

The companion channel uses a distinct locally generated pairing credential; it
never uses or receives the Supervisor token. An explicit Home Assistant config
flow creates the credential with the host CSPRNG and shows it once for
submission through the local add-on ingress pairing UI. Both peers keep the
credential and private session keys only in locked process memory. The config
entry stores non-secret endpoint and peer metadata only. The credential never
appears in files, backups, command arguments, logs, diagnostics, core DTOs, or
the server environment. Restart or removal of either peer destroys the active
epoch and requires explicit local re-pairing. A backup restore therefore
cannot reactivate an old credential or epoch.

P13 must select an admitted FOSS mutually authenticated encrypted transport.
Both peers prove possession of the pairing credential and authenticate the
complete handshake transcript. Every request binds protocol version, key
epoch, direction, connection nonce, monotonic per-connection sequence, stable
operation ID, node-attempt ID, plan digest, session, capability, catalog
generation, context ID, and caller ID. Duplicate, out-of-window,
wrong-direction, cross-connection, field-substituted, and old-epoch messages
fail before execution. Server authentication is mandatory; network location
is not identity.

Rotation is an explicit local re-pair transaction. A pending credential cannot
authorize execution. Activation invalidates the old epoch, all old
connections, operation IDs, and continuation/confirmation state; interruption
leaves at most the previously active in-memory epoch usable and never accepts
both epochs for execution. Restart or removal of either config entry revokes
the channel. P13/P14 test provisioning, memory handling, interrupted rotation,
restart, backup restore, revocation, replay, reflection, peer substitution, and
stale-session rejection.

An operation ID is allocated once before first dispatch and remains stable
across reconnects and response retries within one pairing epoch. The companion
keeps a bounded in-memory result ledger for at least the maximum session and
retry lifetime. It reserves the operation and node-attempt IDs before the
effect. A completed duplicate returns the cached typed result without another
effect. An in-flight request whose response is lost returns `Indeterminate`
until explicit Home Assistant state reconciliation establishes completion; it
is never dispatched again blindly. Expired or unknown old IDs are rejected,
not treated as new work. A peer restart destroys the epoch, rejects all old
operation IDs, invalidates affected sessions, and requires re-pairing plus
state reconciliation before a new attempt.

Every external operation has a documented timeout. Cancellation or timeout
does not prove that Home Assistant stopped the effect. Such an operation
returns a typed `Indeterminate` execution result, stops an ordered graph, and
is not retried until idempotency state or an explicit Home Assistant state
reconciliation proves whether it completed.

The add-on declares Wyoming discovery and `homeassistant_api: true`. The add-on
adapter is the only project process whose allowlisted environment contains the
injected Supervisor token or that can initiate Supervisor/Home Assistant API
connections. That authority is restricted to a pinned read-only catalog and
capability synchronization command allowlist. The adapter cannot call
services, fire events, process conversations, write states or configuration,
or use any other effect-producing endpoint; static call-graph checks and a
deny-by-default API mock enforce this boundary. It relays authenticated typed
requests to the companion but cannot execute them.

The companion is the in-Home-Assistant half of the `ha-adapter` subsystem and
is the only project component that executes, using Home Assistant's internal
typed APIs with the original caller context and the live permission checks
above. It never receives the Supervisor token. The NLU server receives an
allowlisted environment with both credentials removed. The add-on adapter and
server run under distinct unprivileged UIDs. The adapter is the container entry
process: it reads the injected token, removes it from the inherited
environment, starts the server under its dedicated UID, and drops its own
privileges before accepting traffic. The server cannot read adapter
environment or memory through procfs.

Adapter/server communication uses a versioned, bounded Unix-domain socket in a
dedicated IPC directory, mode `0660`, a group containing only the two service
identities, and kernel peer-credential checks for every connection. The token
is never placed on a command line, inherited by server or child workers,
persisted, included in core DTOs, or logged. P14 tests effective UIDs, groups,
socket permissions, peer rejection, process environments, and procfs access,
not only child-environment filtering.

The adapter synchronizes immutable entity/device/area/floor and capability
snapshots. Core and language crates have no network capability. The server may
accept bounded local protocol and Wyoming connections but has no outbound
network client and no Home Assistant credential.

The initial compatibility floor is Home Assistant 2026.8.3 on `amd64` and
`aarch64`, matching current official add-on architecture practice. P14 must
also test the latest stable release available at build time. A release may add
architectures only after reproducible native package and install tests.

Wyoming's current conversation bridge does not carry the project's complete
clarification outcome, ordered execution contract, caller authorization
context, or an explicit continuation flag. P12/P13 must run a contract test
before freezing transport behavior. The companion is required for every flow
that would otherwise lose those semantics. Wyoming remains a zero-companion
recognition and safe-read compatibility surface, not permission to weaken
authorization, clarification, ordering, timeout, or partial-execution rules.

Utterances, entity IDs/names, aliases, areas, floors, devices, catalog
snapshots, and session state are sensitive residential data. They remain local,
are not used for telemetry, and are not written to logs, metrics, crash dumps,
or diagnostics. Utterances and sessions are memory-only and TTL-bound. Catalog
snapshots are rebuilt from Home Assistant and are not persisted by default.
Any future opt-in persistence requires owner-only permissions, bounded
retention, explicit deletion, backup disclosure, and a separate privacy ADR.
Protocol and core DTOs may carry only schema-authorized residential fields
needed for the current bounded request or typed outcome, such as original
utterance bytes and referenced stable entity IDs. They never carry credentials,
unreferenced catalog records, bulk residential state, or convenience copies of
fields that the current operation does not require.

The companion is packaged as an open-source custom integration beside the
add-on. P14 pins Home Assistant's custom-component loader, config-flow,
config-entry, auth-manager, permission, service-dispatch, and backup-restore
contracts. P15 installs both deliverables into a clean supported Home Assistant
instance and proves removal, upgrade, restart/re-pair, and rollback behavior.

## Alternatives

1. Call `/api/conversation/process` and delegate NLU to Home Assistant.
   Rejected because it bypasses this engine and mixes interpretation with
   execution.
2. Ship only a custom Home Assistant integration. Rejected as the initial path
   because Wyoming already provides an official local conversation-agent
   contract and Supervisor discovery.
3. Let the add-on execute arbitrary services directly. Rejected because it
   bypasses registered intent handlers, typed policy, and least privilege.

## Consequences

- Wyoming-safe read-only recognition needs no custom Home Assistant component.
- Wyoming action coverage is intentionally narrow until each handler proves
  context, target, timeout, and partial-success safety.
- Catalog synchronization still needs a local API token isolated to the
  adapter process.
- Caller-authorized execution occurs in the companion with the original Home
  Assistant context, not under the Supervisor identity.
- Pairing must be repeated after either peer restarts; this is the deliberate
  cost of keeping credentials and revoked epochs out of persistent backups.
- Clarification/session fidelity is an explicit compatibility gate rather than
  an assumption.
- An ephemeral Home Assistant 2026.8.3 instance and a latest-stable instance
  are required in P14; a hand-written mock alone cannot pass.
- P14 tests prove that schema-authorized current-request residential fields
  round-trip through DTOs while unrelated residential canaries never enter
  DTOs, server/core environments, logs, errors, metrics, files, crash output,
  or diagnostics.

## Rollback

Disable Wyoming discovery or disable companion execution while retaining the
versioned local recognition API. A protocol upgrade is isolated to the
two-part adapter boundary and server; core outcomes do not change.
