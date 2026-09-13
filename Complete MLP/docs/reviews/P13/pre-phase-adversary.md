# P13 Pre-phase Safety And Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04df3-2aba-7960-adc1-3e61e1f4b561`
- Input commit: `1b28fd9ef334540539118b17250a0f46b43b0ed1`
- Input tree: `c82dfe4a51b660ada0784cf9685117ccc4c7bb85`
- Mode: read-only independent primary-evidence inspection
- Independence: repository and tracked public evidence only; no edits, network,
  siblings, prohibited sources, or offensive tooling
- Result: `THREAT_PLAN_SELECTED_CANDIDATE_NOT_ADMITTED`

## Primary Evidence

The review inspected `docs/evidence/REQUIREMENTS-TRACEABILITY.md`,
`docs/security/TRUST-BOUNDARIES.md`, ADR-0004, ADR-0007, ADR-0018,
`crates/protocol/`, `crates/nlu-core/src/semantic_plan.rs`,
`crates/session-engine/`, and `docs/clean-room/MATERIALS.yaml`.

The baseline contains strict protocol v1 and bounded session primitives, but
no P13 policy, protocol-v2, or server implementation. Home Assistant and
Wyoming remain `OPEN_REFERENCE`; executable compatibility proof is required
before transport behavior freezes.

## Fail-closed Invariants

### Policy

- Keep interpretation and policy dependency boundaries separate.
- Use a closed capability, operation, and risk matrix. Unknown, disabled,
  malformed, or unclassified values deny.
- Never accept raw Home Assistant service names or arbitrary payloads.
- Evaluate the complete graph. Any denied node, stale generation,
  contradiction, `NonExecutable` graph, or unsupported atomic requirement
  denies the entire plan without emitting a subset.
- Bind one-time confirmation to the exact canonical plan digest, session,
  capability, and catalog generation. Mismatch, expiry, replay, or concurrent
  reuse denies.
- Confirmation is not caller authorization. Until P14 supplies authenticated
  caller and epoch bindings, no external effect is permitted.

### Protocol v2

- Introduce v2 for `ComposedPlan`, continuation, complete typed outcomes, and
  diagnostics; retain strict byte-compatible v1 decoding.
- Reject unknown versions, fields, tags, duplicates, escaped duplicates,
  malformed UTF-8, trailing bytes, invalid spans, invalid graphs, and
  incompatible field combinations.
- Enforce byte, string, nesting, numeric, collection, graph, diagnostic, and
  framing limits before material allocation.
- Canonical encoding preserves execution class, clauses, relation evidence,
  independent pairs, argument sharing, ordering, and catalog generation.
- Diagnostics use closed codes and bounded counts. They contain no credential,
  utterance, entity data, caller authority, raw service name, or hostile input
  echo.

### Credential-free Server

- Bind only explicitly documented local listeners and contain no outbound
  client path, including loopback fallback.
- Start from an explicit environment allowlist and retain no
  credential-bearing DTO, field, cache, closure, log, or process-memory copy.
- Validate a complete immutable snapshot before one atomic exchange. Each
  request observes exactly one generation; invalid, stale, or interrupted
  reload retains the prior snapshot.
- Bound connections, queued work, concurrent requests, frame reads, request
  time, reload size, and health output.
- Health exposes only closed readiness, version, and count information without
  residential values.

## Required Negative Tests

- Exhaustively enumerate every policy cell and mutate capability, operation,
  risk, plan digest, session, generation, and confirmation independently.
- Race confirmation against duplicate consumption, cancellation, expiry,
  catalog invalidation, and reload; at most one decision may succeed.
- Preserve every v1 fixture exactly while testing all v2 outcome variants and
  semantic fields.
- Test zero, exact, and one-over protocol limits; malformed framing;
  fragmented and coalesced frames; unknown versions; duplicate fields;
  invalid UTF-8; invalid graphs; stale entities; and diagnostic overflow.
- Run retained deterministic fuzz and exhaustion corpora with bounded time and
  memory.
- Inspect bound sockets and deny every attempted outbound connection.
- Inject distinct environment and memory credential canaries and require
  complete absence from the server.
- Race requests, health reads, failed reloads, and valid reloads; reject
  mixed-generation observations.
- Place residential canaries in utterance, entity, alias, session, and catalog
  fields, then inspect errors, debug output, health, metrics, logs, files, and
  crash output.
- Reproduce the exact tracked Wyoming contract for clarification, ordering,
  caller context, and continuation. Any loss requires the companion path or
  abstention.

## Rollback Criteria

Any false allow, partial plan after denial, confirmation substitution, v1
regression, semantic loss, credential exposure, outbound connection, mixed
snapshot, unbounded exhaustion, or residential-data leak is a P0 through P2
blocker.

Rollback disables v2 execution and companion/Wyoming action routing while
retaining strict v1 recognition. A failed reload retains the prior validated
snapshot. No rollback may introduce plaintext, arbitrary services, persistent
credentials, semantic downgrade, or guessed authorization.

## Counterexample

Session `FIXTURE_TECNICA_S` confirms plan digest A for capability A. During an
atomic reload, plan B for capability B becomes current. If confirmation lookup
checks only the session, a concurrent request for B can reuse A's consent. The
required result is denial with no plan subset or effect. A request already
admitted against the old immutable snapshot may finish only under that same
snapshot and exact digest.

## Bounded Convergence

One convergence pass is one integrated selection and disposition of the
closed policy model, protocol-v2 schema and limits, immutable server design,
Home Assistant/Wyoming compatibility proof, and associated negative-test
portfolio. This is pass 1 of at most 3.

P13 permits at most three substantive frozen candidate rounds. Rounds 2 and 3
are blocker-remediation only. The first baseline satisfying all owned rows,
required checks, same-baseline reviewer passes, zero open P0 through P2
findings, and checkpoint validation must be frozen immediately. Failure after
pass or round 3 stops P13 for explicit scope adjudication.
