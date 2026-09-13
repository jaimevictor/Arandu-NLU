# P14 Pre-phase Safety And Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a05ac4-14c6-7392-81f6-d2fee8c8538c`
- Input commit: `371ba75966c435e4d2026a24e427b8f35da79115`
- Input tree: `6291bd5d349c79b9ac62d5b4ab324ad29628b61f`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `THREAT_PLAN_SELECTED`

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P14-A01` | A client injects caller identity or replays a request under another caller. Accept identity only from Home Assistant `ConversationInput.context` and authenticate every bound caller/context field. |
| P0 | `P14-A02` | The adapter executes through a generic service, event, state, conversation, or configuration endpoint. Use a closed read-only adapter allowlist and make the companion the sole execution component. |
| P0 | `P14-A03` | A timeout, cancellation, reconnect, or lost response duplicates an external effect. Reserve identities before dispatch and return cached or `Indeterminate` results without blind retry. |
| P0 | `P14-A04` | A transactional graph partially executes. Abstain before the first effect unless one whole-graph operation has a pinned zero-or-all contract. |
| P1 | `P14-A05` | Session, confirmation, plan, catalog, policy, capability, or operation state crosses a pairing epoch. Bind every state item to the epoch and destroy it on restart or re-pair. |
| P1 | `P14-A06` | The server reads the Supervisor token or companion secret through environment, arguments, procfs, memory, files, backups, dumps, or logs. Use distinct identities, process locking, dump denial, environment deletion, procfs isolation, and canaries. |
| P1 | `P14-A07` | A foreign local process connects to adapter/server IPC. Require a dedicated directory, exact `0660` mode, restricted group, and kernel peer credentials on every connection. |
| P1 | `P14-A08` | Revocation, target expansion, stale catalog state, or prior-node output changes authorization between graph nodes. Re-resolve and reauthorize immediately before every effect. |
| P1 | `P14-A09` | Wyoming loses caller, ordering, clarification, continuation, or partial-success semantics. Route every such plan to the companion or abstain. |
| P1 | `P14-A10` | Wrong-direction, cross-connection, duplicate, out-of-window, field-substituted, or old-epoch authenticated traffic reaches execution. Bind and verify the complete request transcript before ledger reservation. |
| P1 | `P14-A11` | Rejected or unreviewed transport source becomes natively reachable. Build both Linux architectures from read-only source and inspect exact native reachability before enabling runtime. |
| P2 | `P14-A12` | Credential or residential values escape through errors, diagnostics, metrics, crash output, DTO convenience fields, or response rendering. Use closed codes, allowlisted fields, redacted formatting, and distinct canaries. |
| P2 | `P14-A13` | Ledger capacity, TTL arithmetic, rollback, or eviction turns an old identity into new work. Use checked logical time, bounded state, explicit expired tombstones, and fail-closed rollback. |
| P2 | `P14-A14` | A deterministic mock hides an incompatibility with real Home Assistant. Require pinned 2026.8.3 and exact latest-stable ephemeral suites in addition to mocks. |

## Required Schedules

Enumerate both orderings of reservation versus duplicate receipt, dispatch
versus timeout, completion versus cancellation, response loss versus reconnect,
epoch revocation versus every channel transition, authorization versus user
revocation, target expansion versus permission checks, and prior-node result
versus next-node revalidation.

Every schedule must preserve one operation identity, issue at most one external
effect per node attempt, and produce a deterministic typed result. When the
effect outcome cannot be proven, the only permitted result is
`Indeterminate`.

## Required Mutations

Mutate protocol version, epoch, direction, nonce, sequence, operation ID,
attempt ID, plan digest, session, capability, catalog generation, context ID,
caller ID, operation tag, target, permission, timeout, and prior result one at
a time. Exercise duplicate, reflected, cross-connection, reordered, expired,
unknown, stale, and restart-bound variants.

Inject independent credential, utterance, entity, area, device, caller, and
catalog canaries. Inspect arguments, environments, procfs, files, backups,
logs, diagnostics, metrics, errors, renderer output, panic output, and crash
artifacts. Test exact and one-over frame, queue, ledger, target, node, and TTL
limits.

## Linux And Runtime Gates

Linux-only validation must exercise effective UIDs and groups, `SO_PEERCRED`,
socket ownership and mode, procfs environment and memory denial, process-wide
memory locking, dump denial, fresh socket-generation directories, server
outbound denial, and native amd64/aarch64 compilation from kernel-enforced
read-only source.

The Home Assistant suites must prove current-user lookup, per-target
`POLICY_CONTROL`, admin revocation, caller-context preservation, no generic
dispatch, timeout and late completion, bundle snapshot zero-or-all behavior,
config-flow one-time pairing, restart revocation, and backup non-restoration.

## Counterexample

An ordered graph reserves operation O in epoch E. Home Assistant applies node
one, the response is lost, the caller is then revoked, and a reconnect submits
O under epoch E with a changed target while a second request reuses O under
epoch E+1. Any implementation that keys only by operation ID or checks
authorization once can duplicate node one or execute node two without
authority. The required result is a cached or indeterminate node-one result,
no redispatch, rejection of the changed binding, rejection of E+1 reuse, and
no node-two effect.

## Bounded Stop

This is convergence pass 1 of at most 3. Candidate rounds 2 and 3 may address
only reproduced P0 through P2 blockers. Freeze the first minimally acceptable
baseline and defer eligible P3 improvements; do not add optional refinement.

## USR-043 Final Remediation Addendum

Pass `1 of 1` must reject these frozen counterexample families:

- a canonical production submission repeated after multiple retention cohorts
  or forged as `INITIAL`;
- a multi-effect operation with evidence for only one effect, unrelated live
  state, mismatch followed by recovery, or capacity exhaustion by probes;
- rollback or exception from the shared logical clock at any consumer;
- restart-marker persistence failure followed by process reconstruction;
- a delayed helper reply crossing epoch rotation;
- helper startup failure after binding but before proof, including a process
  whose `terminate()` returns before exit;
- stale normative governance binding, unadmitted validation executables,
  ambiguous historical Noise digest schema, and missing multi-cohort
  tombstone coverage.

Acceptance requires each schedule to fail closed without duplicate effect,
state resurrection, leaked endpoint, capacity overrun, or untyped exception.
