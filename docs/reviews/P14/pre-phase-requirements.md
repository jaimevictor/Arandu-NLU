# P14 Pre-Phase Requirements Analysis

- Phase: `P14`
- Role: requirements
- Mode: read-only primary-evidence analysis
- Input baseline: `371ba75966c435e4d2026a24e427b8f35da79115`
- Result: `READY_WITH_EXPLICIT_CARRY_FORWARD`

## Mandatory Scope

The requirement matrix and manifest define 131 direct `P14-*` obligations.
They cover:

- Home Assistant revalidation, dispatch, timeout, caller authorization,
  catalog generation, and no-generic-call behavior (`P14-HA-*`);
- pinned Home Assistant contracts and one proven zero-or-all multi-node
  operation (`P14-CONTRACT-*`);
- Wyoming recognition and fail-closed routing (`P14-WYO-*`);
- graph execution and per-effect authorization (`P14-EXEC-*`, `P14-AUTH-*`);
- Unix IPC, process/credential isolation, adapter authority, and companion-only
  execution (`P14-IPC-*`, `P14-PROC-*`, `P14-ADAPT-*`);
- operation identity and bounded idempotency (`P14-IDEM-*`);
- credential, residential-data, utterance, rendering, packaging, and
  replaceability boundaries (`P14-PRIV-*`, `P14-RESP-001`,
  `P14-ROLL-*`, `P14-GATE-001`).

Applicable inherited obligations include the P10 catalog/action contracts,
P12 continuation lifecycle, P13 pairing/channel bindings, global
determinism/security/offline/privacy rules, dependency and license gates,
phase convergence limits, and mandatory reviews.

## Minimum Deliverables

1. A Home Assistant add-on adapter and separate credential-free NLU server
   process with bounded typed Unix-socket IPC.
2. A companion custom integration that alone authorizes and executes Home
   Assistant operations.
3. A mutually authenticated Noise channel with process-locked peer secrets,
   explicit pairing epochs, replay/direction/connection binding, and restart
   revocation.
4. Late plan, catalog, target, user, permission, policy, and capability
   revalidation before every effect.
5. A bounded operation ledger that distinguishes completed, in-flight,
   indeterminate, expired, and unknown duplicate work.
6. A read-only Wyoming recognition path limited to reviewed safe handlers and
   a companion path for sensitive, expanding, ordered, or caller-scoped work.
7. A deterministic response renderer separate from interpretation, policy,
   and execution.
8. Deterministic mock tests, pinned Home Assistant 2026.8.3 tests, a frozen
   latest-stable test identity, install/upgrade/rollback coverage, and native
   amd64/aarch64 Linux builds from kernel-enforced read-only source.

## Source And Gate Constraints

Only the P13-selected Noise/Snow profile may enter the product. The rejected
CPython/OpenSSL portfolio remains prohibited. Every base image, runtime,
build tool, Python package, and test dependency requires independent FOSS
admission before execution or distribution. Home Assistant developer
documentation marked `EXPOSURE_REJECTED` is unusable.

P14 carries the user-directed P13 validation debt: its native source-admission
gate must recompute the selected source inventory and any stale P13
self-binding values before enabling the transport runtime.

## Counterexample And Open Decision

An ordinary Home Assistant service call over two targets can apply the first
effect and fail or time out on the second. Treating that one dispatch as
atomic violates `P14-CONTRACT-008`. P14 must identify a pinned operation whose
contract proves zero-or-all behavior at every failure point or fail closed
before the first effect for every graph requiring atomicity.

The mutable phrase "latest stable at build time" must resolve to an exact
version and source commit before candidate freeze. Native means actual Linux
execution on both amd64 and aarch64 unless an accepted ADR establishes an
equivalent stronger proof.

## USR-043 Final Remediation Addendum

- Authorization baseline:
  `aeac316eafa065b8c36fece92afa9c6b333c2eea`
- Failed subject: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Pass unit: one integrated correction approach for the fourteen frozen
  blocker IDs, ending when that approach is frozen, dispositioned, or rejected
- Pass budget: `1 of 1`

This pass owns only the fourteen blockers in the immutable terminal blocker
report. Minimum acceptance requires exact blocker regressions, the complete
P14 and governance gates on one clean immutable subject, byte-identical P13
paths, all transferred P15 gates still disabled, and six independent
same-subject `PASS` verdicts. Any remaining P0 through P2 finding is terminal;
there is no optional refinement.
