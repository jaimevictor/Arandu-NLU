# ADR-0037: P14 adapter and companion boundary

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-01
- Owners: P14-P15

## Context

ADR-0007 requires a two-part Home Assistant boundary: the add-on adapter alone
holds Supervisor authority, while the companion integration alone authorizes
and executes Home Assistant operations. ADR-0022 admits a Rust Snow transport
portfolio. Home Assistant custom integrations are Python, and implementing
Noise independently in Python would introduce a second cryptographic
implementation outside the selected source portfolio.

P14 must also preserve a credential-free NLU server, kernel-authenticated local
IPC, caller and pairing-epoch bindings, deterministic idempotency, and one
reviewed zero-or-all multi-node capability.

## Decision

The product has four runtime roles:

1. the Rust add-on adapter is the container entry process, synchronizes
   read-only Home Assistant state, and owns the Supervisor token;
2. the Rust NLU server interprets requests over bounded local IPC and receives
   no Home Assistant or pairing credential;
3. a Rust companion channel helper owns the companion pairing credential and
   terminates the selected Noise channel; and
4. the Python custom integration receives typed requests from its local helper
   and is the only component that authorizes and executes Home Assistant
   operations.

The Rust adapter and helper share one transport library built only from the
P13-selected Noise revision 34 and Snow 0.10.0 source projection. The Python
integration never implements cryptography. The helper cannot call Home
Assistant APIs. It relays only closed typed operations over a private bounded
local socket whose peer identity is checked by the kernel.

Pairing credentials are provisioned once through a local Home Assistant config
flow and add-on ingress transaction. A one-time inherited pipe may carry the
credential to a freshly started helper; command arguments, environment,
persistent config, logs, diagnostics, and backups may not. Both Rust peers
lock their complete address spaces before accepting the credential and fail
startup when locking or dump denial is unavailable. Restart or removal
destroys the epoch and requires local re-pairing.

Every authenticated request binds protocol version, epoch, direction,
connection nonce, sequence, operation ID, node-attempt ID, canonical plan
digest, session, capability, catalog generation, Home Assistant context ID,
caller ID, typed operation, and exact targets. The Python integration
revalidates all semantic and authorization fields before every effect.

The operation ledger is bounded, in-memory, epoch-scoped, and reserves work
before dispatch. Completed duplicates return cached results. In-flight,
cancelled, timed-out, expired, and unknown duplicates never dispatch blindly;
an unprovable outcome is `Indeterminate`.

The initial zero-or-all multi-node capability is a read-only bundled state
snapshot. One event-loop callback validates every target and returns the whole
typed bundle or no result. It performs no external effect, so partial effects
are impossible at every failure point. Effect-producing transactional graphs
remain unsupported and abstain before dispatch.

Wyoming is recognition-only and advertises one installed PT-BR
`IntentProgram`, never `HandleProgram`. Only reviewed single-target read-only
handlers may use its compatibility path. All other plans use the companion or
abstain.

## Consequences

- The companion package includes architecture-specific Rust helper binaries
  beside the Python integration.
- P14 and P15 must test helper startup, local peer identity, process memory
  controls, restart revocation, and install/upgrade/rollback for both
  architectures.
- The adapter cannot execute, and the helper cannot authorize or execute.
- No second Noise implementation or generic Home Assistant service gateway is
  introduced.
- Atomic effect-producing graph execution remains intentionally unsupported.

## Rollback

Disable companion execution and Wyoming discovery while retaining the
versioned local recognition API. Removing either Rust channel peer revokes the
active epoch. Rollback never enables plaintext transport or add-on execution.
