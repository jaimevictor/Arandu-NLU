# ADR-0052: Entity resolution activation plan (revision 3)

- Status: `PROPOSED_NOT_ACCEPTED`
- Date: 2026-09-17 (revision 3 supersedes revision 2 in place)
- Supplements: ADR-0050 (MLP), ADR-0051 (entity-resolution implementation)
- Scope: plan only. No wiring is implemented by this ADR. The resolver remains
  an additive, unwired library API (`addon/engine/src/resolution.rs`).

Revision 3 is a punctual technical review without architecture redesign. It
fixes: a circular hash dependency in generation; blanket 100% expectations in
structured shadow that ignored legitimate ambiguity; conflated atomicity
claims across interpretation, preflight, and physical execution; an
unspecified split between hashed descriptors and revalidated dynamic state;
ID-bearing telemetry; missing endpoint schemas; and a display-name fallback
that was suggested rather than normatively fixed.

## 1. Boundary model: resolution is not a plan

Four stages with distinct owners. Skipping a stage is forbidden.

1. Resolution (add-on, new): one mention plus typed constraints plus
   generation plus optional span against one immutable snapshot returns
   candidate `registry_id`s with evidence (`resolved`), a candidate list
   (`ambiguous`), or `no_match`. No actions, no ordering, no services.
2. Plan construction (add-on parser, later step): candidates plus the
   utterance action/ordering grammar produce typed operations. Atomic: every
   clause resolves or there is no plan, exactly as `interpret()` does today.
3. Atomic validation and preflight (integration, mirrors `runtime.py`):
   re-resolve every `registry_id` against the live registry; re-derive the
   snapshot and compare for equality; check exposure, availability, domain,
   service support, and caller permission for the complete plan before the
   first effect; revalidate before each service call.
4. Execution (integration only): per-domain service calls with the original
   caller context.

`ResolutionOutcome` must never convert directly into a service call. The v2
response parser (integration side, sibling of `protocol.py`) yields
candidates only, never operations. `ambiguous` and `no_match` short-circuit
before plan construction. The existing contradiction rule (no target reused
across effect operations) and the complete-plan preflight apply unchanged to
any plan that consumed resolver output.

Atomicity has three distinct layers that must not be conflated:

- Interpretation atomicity (add-on): `interpret()` resolves every clause
  before returning; any ambiguous or unmatched clause aborts the whole
  request, so no partial plan is ever published. The resolver itself is a
  pure function over one mention and holds no partial state.
- Preflight atomicity (integration): the complete plan is validated
  (re-resolution, snapshot equality, exposure, availability, domain, service
  support, caller permission) before the first effect. A plan that fails
  preflight executes nothing.
- Physical execution is not atomic and has no transactional rollback. The
  runtime calls services sequentially per domain (`runtime.py`
  `_async_execute`); if call k+1 fails, the first k effects stay applied and
  the result is `execution_failed` with `operation_count=k`. There are no
  compensation actions. Recovery is a new request: rebuild the snapshot,
  re-resolve, re-preflight, and execute again. Any consumer of resolver
  output inherits exactly these semantics; documentation and user-facing
  messages must never imply all-or-nothing execution.

## 2. Generation ownership and lifecycle

- Authoritative origin: the integration's live registries at snapshot-build
  time (`entity_registry`, `device_registry`, `area_registry`, entity states),
  the same sources `catalog.py` already reads.
- Canonical hash input (no circularity): SHA-256 is computed over the
  canonical JSON serialization (sorted keys, compact separators, UTF-8) of
  the snapshot descriptor set only: `catalog_id`, per area (`area_id`,
  `names`), and per entity (`registry_id`, `entity_id`, `domain`,
  `area_id`, `display_name`, `aliases`, `capabilities`). The `generation`
  field itself is excluded from its own hash input; it is assigned after
  hashing. Full hex digest (64 bytes, fits `MAX_GENERATION_BYTES`).
- Invalidating changes: any change to the hashed descriptor set (entity or
  area membership, identifier or dotted-ID change, domain change, area
  rebinding, display/alias/capability change, area rename) produces a new
  generation. Live state values (on/off, temperature readings, other
  attribute values) never enter the hash and never flip the generation;
  they are revalidated separately (section 5). Availability flips
  membership at build time (unavailable/unknown states are skipped, as in
  `catalog.py`), so an availability flip correctly invalidates via
  membership change.
- Binding: generation is a field of the snapshot and is echoed in the
  request. The add-on checks request generation against snapshot generation
  (self-consistency: catches transport mix-ups, proves nothing about
  freshness).
- Freshness verification (integration side, the v1 pattern in `runtime.py`):
  after the response arrives, rebuild the snapshot from live registries and
  require payload equality, re-resolve every ID against the live registry,
  and revalidate before each call. Three layers: equality, preflight,
  per-call revalidation.

A hash supplied by any client is never proof of actuality. The add-on treats
generation as a consistency tag; only the integration's re-derivation proves
freshness. Stale input fails closed at every layer.

## 3. Compatibility strategy

- Protocol v1 and its behavior are frozen. `POST /v1/interpret` keeps exact
  byte-identical outputs, enforced by `regression_gate.py` (144 Phase A +
  23 Phase B cases against historical baselines). Any behavioral change to
  v1 semantics requires a new corpus, a new freeze, and a new contract
  version; historical baselines are never edited or re-labeled.
- New semantics live behind versioned contracts only (`/v2/resolve`, later a
  v2 interpret shape if Step 6 requires one). Unknown paths keep the existing
  404/`invalid_request` behavior; v2 envelopes use `deny_unknown_fields`.
- Old clients never send v2 traffic; new clients keep v1 working.

## 4. `/v2/resolve` endpoint contract

- Route: `POST /v2/resolve`, `Content-Type: application/json`, same server
  (`server.rs`) with version-agnostic routing first, then strict
  per-version deserialization. `GET /health` unchanged.
- Effective schemas: none exist yet for the active contracts. The files
  under `schemas/protocol-v1-*.schema.json` and `schemas/protocol-v2-*.schema.json`
  describe a retired envelope (`{version, request}`, sessions, integer
  generations, composed plans) that matches neither the real v1 HTTP
  contract nor the resolver types; they are historical artifacts under
  ADR-0050 and must not be referenced as endpoint schemas. The effective
  request/response schemas are exactly the Rust serde types
  (`ResolutionRequest`, `ResolutionOutcome` with `deny_unknown_fields`) with
  the bounds below. Step 1 acceptance requires machine-readable JSON Schema
  files derived 1:1 from those types (no new semantics) and validated
  against live probe traffic in both directions:
  - request: `text` (string, 1..2048 bytes, no control chars),
    `catalog` (`catalog_id` identifier 1..128 bytes; `generation`
    identifier 1..64 bytes; `areas` 0..256 items of `area_id` plus 1..8
    names of 1..128 bytes; `entities` 0..1024 items of `registry_id`,
    `entity_id` 1..255 bytes, `domain` from the closed set,
    optional `area_id`, `display_name` 1..128 bytes, `aliases` 0..8 items
    of 1..128 bytes, `capabilities` 1..4 actions), request `generation`
    1..64 bytes, `mention` (1..255 bytes, no control chars), optional
    `span` (exactly two byte offsets), `constraints` (optional `area_id`,
    `domain`, `capability`); unknown fields rejected;
  - response: `{"outcome":"resolved","registry_id","evidence"}` with
    evidence `external_entity_id` | `explicit_registry_alias` |
    `display_name_with_constraint`; or
    `{"outcome":"ambiguous","candidates"}` (2 or more canonically sorted
    stable IDs); or `{"outcome":"no_match"}`; unknown fields rejected.
- Input bounds (shared with the library): as listed above. Transport bounds
  unchanged: 64 KB request, 64 KB response, 3 s I/O deadline.
- Error taxonomy: transport-malformed (bad JSON, oversized body, wrong
  method/path, duplicate content-length) keeps existing server behavior
  (4xx plus `invalid_request`-shaped body). Resolution-malformed (invalid
  span, stale generation, duplicate identity, contradictory or unknown
  evidence) returns HTTP 200 with `{"outcome":"no_match"}`: `no_match` is a
  valid resolution answer, not a transport error. The two classes must never
  be conflated in client handling.
- Local exposure: identical trust model to v1. The server binds the
  configured local address; the integration client reuses its allowlist
  (RFC 1918, loopback, ULA, `localhost`, single-label `local-*`, `.local`,
  `.home.arpa`), DNS pinning with locality verification, no redirects, HTTP
  only, 3 s timeout. No Home Assistant credentials cross this boundary in
  either direction (MLP-012 extends to v2).
- Privacy and telemetry: no utterance, mention, span, catalog, snapshot, or
  candidate content is logged or persisted by the add-on (`server.rs` has no
  request logging today) or the client (no logging); all resolution state is
  request-local; the conversation entity retains nothing. Shadow telemetry
  (Steps 3/5) retains aggregate counters only, for example per probe-class
  outcome counts (`identity_entity_id/resolved`, `display/unconstrained-tie`,
  `negative/no_match`) and the measured ambiguity rate. No `registry_id`,
  mention text, span, or utterance-derived value is persisted, including in
  hashed or salted form. Utterances in utterance shadow (Step 5) are
  processed ephemerally in memory: the replay worker holds one utterance at
  a time, emits only its counter increment, and never writes utterance text
  to disk, logs, or reports. Counter schemas are fixed before collection
  starts so that no free-text field can smuggle content into telemetry.

## 5. Snapshot builder feasibility against real Home Assistant data

Field-by-field mapping from the current `catalog.py` sources:

- `registry_id`: `entry.id` (stable entity-registry UUID). Available and
  stable. The runtime already re-resolves it against the live registry and
  rejects `entity_id` drift as stale; ER-resolved IDs pass through the same
  check.
- `entity_id`: `entry.entity_id` (dotted, mutable). Available.
- `display_name` (normative rule, derived from `catalog.py`, not a
  suggestion): first non-empty value of `friendly_name` state attribute,
  `entry.name`, `original_name_unprefixed`, `original_name`, in exactly this
  priority, which is the tuple order `_entity_names` already uses. `aliases`
  are exactly the sorted, bounded `entry.aliases` (at most 8 items of at
  most 128 bytes, control characters rejected). No other name source may
  contribute. Entities with no usable display name are skipped at build
  time, mirroring the existing skip for nameless entities; such entities
  stay invisible to both v1 and ER snapshots. A different fallback order
  would change user-visible behavior and therefore requires a versioned
  contract change, never a silent edit.
- `area_id`: entry area or device area, as today. Available.
- `capabilities`: derived from service availability plus fan feature flags,
  mirroring `_actions` (`turn_on`/`turn_off`/`set_fan_percentage` gated per
  domain, `get_state` always). Available. Because capabilities are hashed,
  a feature or service change correctly invalidates the generation.
- `generation`: new. Computed as defined in section 2.
- Unregistered entities: `build_catalog` iterates registry entries only, so
  states without a registry row are excluded from v1 today and stay excluded
  from ER snapshots. Coverage is registry-bound by design; this is a
  documented limitation, not a gap to close with heuristics.
- Hashed versus revalidated (no unnecessary invalidation, no lost safety):
  the generation hash covers only the descriptor set of section 2. Live
  state values, attribute values beyond capability derivation, caller
  permissions, and service liveness are excluded from the hash and
  revalidated separately at preflight and per call (availability via
  `STATE_UNAVAILABLE`/`STATE_UNKNOWN`, exposure via
  `async_should_expose`, service and feature presence, permission policy,
  `registry_id`-to-`entity_id` binding, area binding). Value-only changes
  therefore never invalidate a snapshot, while anything that changes what
  the snapshot claims always does.
- Real-data collision risk: duplicate normalized display names across areas
  are expected and must yield `ambiguous` (fail-closed); structured shadow
  (Step 3) quantifies how often, with no product impact.

## 6. Implementation sequence

### Step 1 — read-only `/v2/resolve` endpoint (additive transport)

Changes: version-agnostic route branch in `server.rs`; v2 request/response
types already exist in the library; integration `LocalNluClient.async_resolve`
reusing endpoint validation, bounds, timeout, and DNS pinning; v2 response
parser yielding candidates only; machine-readable JSON Schema files derived
1:1 from the section 4 tables (no new semantics).

Acceptance (objective): ER 21-row corpus passes through HTTP with zero gold
mismatches; request and response schemas validate live probe traffic in both
directions with a schema validator; malformed transport inputs keep existing
4xx behavior; resolution-malformed inputs return 200/`no_match`;
`regression_gate.py` clean; no v1 code path touched except the additive
route branch. Rollback: remove the route branch.

### Step 2 — snapshot builder with generation (integration side)

Changes: `catalog.py` gains an ER snapshot constructor implementing the
section 5 mapping plus section 2 generation; frozen translation fixtures
with pinned display fallback order.

Acceptance: fixtures round-trip byte-identically; generation equals recompute
over the same registries; any descriptor change flips the generation while
state-value-only changes do not; disabled, unexposed, unavailable, unknown,
display-less, and unregistered entities never enter the snapshot. Rollback:
delete the constructor; v1 path untouched.

### Step 3 — structured shadow (no extraction contract needed)

The dependency defect in the previous proposal is fixed by restricting this
shadow to structured inputs. For each live-built snapshot, the integration
sends tier-separated probes whose expectations are derived from the snapshot
itself under ADR-0051 tiers; no blanket 100% self-resolution is required and
legitimate ambiguity is preserved, never resolved away:

- entity-ID probes: each entity's exact dotted `entity_id` as mention, no
  constraints. Expected: `resolved` to itself (tier 1; snapshot validation
  guarantees unique dotted IDs). A normalization collision between two
  distinct dotted IDs must yield `ambiguous`; that outcome is correct and
  recorded, not a failure.
- Alias probes: each explicit alias as mention, no constraints. Expected per
  alias group: unique alias resolves to its owner; an alias shared by N
  entities yields `ambiguous` with all N candidates.
- Display probes, unconstrained: each display name as mention. Expected:
  a display unique in the catalog yields `no_match` (display alone never
  resolves); a display shared by N entities yields `ambiguous`.
- Display probes, constrained: each display name with its owner's own area
  and domain constraints. Expected: exactly one admissible candidate
  resolves; same-area same-display twins yield `ambiguous`; a display whose
  owner set is fully filtered out yields `no_match`.
- Negative probes: unknown strings, empty mentions, contradictory
  area/domain/capability constraints, and stale generations must yield
  `no_match`.

No utterance understanding is involved, so no extraction contract is
required.

Acceptance: zero probe mismatches against the contract-derived expectations;
the measured legitimate-ambiguity rate on real snapshots reported as
aggregate counters only (section 4); shadow traffic is never acted on
(assert at the call site: results go to telemetry only). Rollback: stop
sending probes.

### Step 4 — mention-extraction contract (largest open work)

Specify who derives mention, span, and typed constraints from an utterance
plus snapshot, with an independent corpus, oracle, and freeze under the
established preparation discipline. This was previously scheduled after
shadow mode although shadow depends on it; the reorder in Step 3 removes
that dependency for structured inputs, and this step unblocks
utterance-level work.

Acceptance: frozen corpus/oracle/freeze for extraction; structured-shadow
inputs validate against it; no product behavior changes. Rollback: the
artifacts are inert without callers.

### Step 5 — utterance shadow (after extraction exists)

Replay real utterances through extraction plus `/v2/resolve` in
observe-only mode; compare against v1 plans for telemetry.

Acceptance: zero resolver `resolved` on oracle `no_match`/`ambiguous` rows;
divergence report reviewed; execution path untouched (telemetry-only assert
retained). Rollback: stop the replay job.

### Step 6 — parser-internal adoption behind the equivalence gate

Only after Steps 4-5: entity-clause resolution may delegate to evidence
tiers while segmentation, area grammar, primaries, ellipsis, ordering, and
plan atomicity stay in the parser. Every clause resolves before any plan
publishes. Requires the section 5 names-split contract so MLP `names` map
deterministically onto display/aliases.

Acceptance: 144 + 23 + 21 corpora green with byte-identical v1 outputs on
MLP corpora via `regression_gate.py`; new mixed corpora cover tier
interaction (precedence suppression versus area expansion, primary versus
alias collisions); any intentional behavior change gets a new corpus row
with justification and versioning, never a baseline edit. Rollback: one
delegation branch restores exact v1 behavior.

### Step 7 — activation decision

A follow-up accepted ADR flips the ledger to ACTIVE, wires the integration
to consume resolved candidates through stages 2-4 of the boundary model,
and defines clarification rendering for `ambiguous` (new contract, new
corpus). Until then the resolver stays available but unused by the product
path.

## 7. Risks

- Primary/alias/display collisions between MLP semantics and ER tiers
  (section 6, Step 6 gate is the mitigation).
- Sparse real-world aliases concentrate load on the display tier; area-less
  entities cannot use area constraints and need domain/capability evidence.
- Weak generation source would turn stale rejection into theater; section 2
  pins computation and section 3 pins verification layers.
- Partial publication across multi-operation plans; the preflight-all rule
  and per-call revalidation carry over and must be re-proven for any path
  consuming resolver output.
- Telemetry in Steps 3/5 retains aggregate counters only with a fixed
  counter schema; no IDs, mentions, spans, utterances, or derived values
  are persisted, and utterance processing is ephemeral (section 4).

## 8. Product decisions required (approval gate)

Only genuinely product-visible choices remain; everything else in this
revision is fixed technically from existing contracts and code.

1. Accept the four-stage boundary, the atomicity layering (interpretation
   and preflight are all-or-nothing; physical execution is sequential with
   no rollback), and the rule that `ResolutionOutcome` never converts
   directly into service calls.
2. Accept the generation lifecycle, especially that freshness is proven by
   integration re-derivation and never by a client-supplied hash, and that
   state-value changes do not invalidate snapshots.
3. Accept the registry-bound coverage limit: states without a registry row
   stay invisible to both v1 and ER snapshots. (The display-name fallback
   order is already fixed normatively in section 5 from `catalog.py`; changing
   it later requires a versioned contract change.)
4. Accept the `/v2/resolve` contract: bounds, error taxonomy, local-only
   exposure, aggregate-only shadow telemetry with ephemeral utterance
   processing, and machine-readable schemas as a Step 1 deliverable.
5. Accept the reordered sequence (structured shadow before extraction
   contract) and the equivalence-gate bar for Step 6.
6. Accept or defer Step 7 activation; until accepted, the resolver remains
   available but unused.
