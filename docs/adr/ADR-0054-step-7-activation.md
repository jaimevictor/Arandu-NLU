# ADR-0054: Step 7 activation proposal (v2 pilot in Home Assistant)

- Status: `PROPOSED_NOT_ACCEPTED`
- Date: 2026-09-18
- Supplements: ADR-0050 (MLP), ADR-0051 (resolution), ADR-0052 (activation
  plan), ADR-0053 (extraction)
- Scope: proposal only. No runtime wiring, no residential traffic, no
  behavior change is implemented by this ADR. Activation requires explicit
  product approval of the decisions in section 9.

## 1. Starting position (audited, not assumed)

Implemented and reachable today: `resolve_entity`, `extract`,
`interpret_v2` as library APIs; `POST /v2/resolve` and `POST /v2/interpret`
on the local add-on; `LocalNluClient.async_resolve` /
`async_interpret_v2`; `parse_v2_response` / `parse_v2_plan`;
`build_er_snapshot` with SHA-256 generations; all schemas, corpora (21 +
30 + 24 rows), freezes, baselines, and runners green on freshly built
binaries (80 Rust + 58 Python tests; A 144/144, B 23/23).

Wired but inert by default: `runtime.py` implements the v2 flow
(pre-selection, `async_interpret_v2`, generation re-derivation, validated
adapter, reused preflight/execution), residential shadow (opt-in,
aggregates-only), and per-request `v2_enabled`/`shadow_enabled` options
(default off) with an options flow. With both flags off the execution
path is v1-only; `conversation.py` renders `ambiguous` generically with
no candidate handling and no clarification flow. `build_er_snapshot`
output (`areas`, `catalog_id`, `entities`, `generation`) matches the
`ResolutionCatalog` wire shape field-for-field, so the client forwards
it without translation.

## 2. v2 runtime flow architecture

One new method beside the v1 flow (v1 code untouched), mirroring
`runtime.py::async_process` stage for stage:

1. `snapshot = build_er_snapshot(hass)` (`CatalogError` → `unavailable`).
2. `raw = client.async_interpret_v2({text, catalog: snapshot.payload,
   generation: snapshot.payload["generation"]})` (`ClientError` →
   `unavailable`). Same endpoint validation, 64 KB bounds, 3 s timeout,
   DNS pinning, no redirects as v1.
3. `plan = parse_v2_plan(raw)` (`ProtocolError` → `unavailable`).
   Candidates-only responses never occur here (`/v2/interpret` returns
   plans or abstentions, never bare candidates).
4. Non-plan outcomes map to the existing `RuntimeResult` codes
   (`ambiguous`, `no_match`) and the existing conversation rendering.
   No new UX is required for activation.
5. Re-derive: `current = build_er_snapshot(hass)`; require
   `current.payload["generation"] == snapshot.payload["generation"]`
   (plus full preflight below). Mismatch → `stale`, same rendering as v1.
6. Preflight the complete plan before the first effect by reusing
   `_preflight`, `_revalidate`, `_async_execute`, and `_query` unchanged,
   with one small pure adapter: ER rows expose `display_name` /
   `capabilities` where preflight reads `names[0]` / `actions`, so
   `er_row_to_allowed(row)` maps
   `{registry_id, entity_id, label: display_name, actions: capabilities}`.
   The adapter validates before mapping and raises like a broken catalog
   otherwise: non-empty display name, known domain, non-empty
   capabilities with every capability supporting the domain, well-formed
   identifiers; aliases are never fabricated and identities pass through
   byte-identically. Area binding stays live-derived at prepare and
   revalidate time (same as v1), never snapshot-carried. Query labels may
   differ textually from v1 (`display_name` versus fused-sorted
   `names[0]`) without changing the resolved identity; that cosmetic
   difference is accepted and must not be "fixed" by inventing names.
   No duplication of permission checks, exposure checks, domain gating,
   contradiction detection, per-call revalidation, or per-domain batching.
7. Execute via the existing effect/query paths with the original caller
   context. A resolved ID is therefore necessary but never sufficient for
   execution: preflight, permission, and revalidation can each still refuse.

## 3. Stage boundaries (unchanged from ADR-0052, repeated for precision)

Resolution (candidates) → plan construction (atomic, add-on) →
validation/preflight (atomic, integration) → sequential execution
(integration, no rollback). Skipping a stage stays forbidden. In
particular, a successful resolution authorizes nothing: `parse_v2_plan`
output still passes generation equality, live re-resolution, exposure,
availability, domain, service, permission, and per-call revalidation
before any service call, exactly like v1 plans.

## 4. v1-or-v2 selection criteria and routing matrix

v1 stays the default path. v2 is considered only with explicit opt-in, and
routing is deterministic pre-selection before any interpretation: commands
outside v2 scope go directly to v1, never attempting v2 first.

Pre-selection rule (integration side, no grammar duplication): route
directly to v1 when the casefolded stripped utterance starts with a query
marker (`qual `, `como `, `quanto ` — exactly the necessary condition the
v1 parser gates queries on) or contains ` e ` (ellipsis and multi-operation
commands, which v2 cannot distinguish without parsing; when classification
is unreliable, v1 is preserved). Otherwise, under opt-in, the request goes
to v2. This conservatively limits v2 runtime coverage to single effect
commands with exact evidence; everything else keeps byte-identical v1
behavior.

Routing matrix (exactly one add-on call per request, never both):

| Situation | Action | Rationale |
|---|---|---|
| Opt-in off | v1 only | Default; v2 unreachable |
| Opt-in on, query marker or ` e ` present | v1 directly, v2 never attempted | Out of v2 scope by contract |
| Opt-in on, single effect command | v2 attempted once | In-scope slice |
| v2 returns a plan | preflight, then execute or refuse | Normal v2 path |
| v2 returns `ambiguous` or `no_match` | terminal abstention, existing rendering | No fallback: abstention is an answer |
| v2 body unparsable (400 class) | terminal `unavailable` | Malformed contract traffic, not a retry signal |
| v2 transport failure or timeout | terminal `unavailable` | Infrastructure errors never authorize an alternative execution |
| v2 plan fails preflight (`stale`, `denied`, contradiction) | terminal, existing rendering | A refused operation is never re-attempted through another door |
| Rebuild failure or generation mismatch | terminal `stale` | Fail closed, no fallback |

Prohibitions: no cross-version retry, no ping-pong (at most one
interpretation call per utterance), no simultaneous v1+v2 plans for one
utterance, no fallback after any v2 attempt for any reason. A denied
caller verdict is terminal. In-flight v2 requests continue terminally if
the flag flips mid-flight; only new requests observe the new flag value.

Alternatives rejected-or-deferred: v1-only forever (valid fallback
position), heuristic per-utterance routing beyond the two rules above
(fragile, not proposed), v2-only (coverage loss; rejected).

## 5. Ambiguity and abstention handling

v2 `ambiguous` and `no_match` map to the existing `ambiguous` /
`no_match` result codes and the existing generic rendering ("be more
specific" / "didn't understand"). v2 abstentions deliberately expose no
candidate lists, so no new UX, strings, or contracts are needed to
activate safely. Candidate-assisted clarification stays a future
enhancement requiring its own exposure contract, UX strings, and corpus;
it is optional, not an activation blocker.

## 6. Generation verification and revalidation

Same three layers as ADR-0052 section 2, now placed in code: (a) request
generation equals snapshot generation (add-on self-consistency);
(b) integration re-derives the snapshot after the response and requires
generation equality (freshness; a client hash alone proves nothing);
(c) preflight re-resolves every ID against the live registry and each
service call revalidates exposure, availability, domain, service,
permission, and bindings. Availability flips invalidate via snapshot
membership change (unavailable states never enter the snapshot);
value-only changes never invalidate. Any layer failing yields `stale`
with the existing rendering; nothing executes.

## 7. Permissions, isolation, rollout, rollback

- Permissions: unchanged model. Caller lookup, active check,
  `POLICY_CONTROL` for effects / `POLICY_READ` for queries, per-entity
  checks, admin rule, `denied` rendering — all reused, not reimplemented.
- Isolation: the add-on receives text plus snapshot only, no HA
  credentials, over local-only HTTP with the existing allowlist, DNS
  pinning, bounds, and timeouts. No utterance, snapshot, or candidate
  content is logged or persisted by add-on, client, or runtime; shadow
  telemetry keeps aggregate counters only.
- Rollout: phase 0, residential shadow — v2 observe-only alongside v1 on
  an approved instance, aggregate telemetry, kill-switch (config flag,
  default off); phase 1, opt-in v2 for the single-effect slice per the
  section 4 matrix (config entry option, default v1-only); phase 2,
  default flip, only with new approval on shadow evidence.
- Kill-switch mechanism: two explicit config entry options,
  `v2_enabled` and `shadow_enabled`, both default `False`, toggled
  through the integration options flow. The runtime reads both through
  callables on every request (no restart, no caching across requests),
  so deactivation returns new requests to the v1 flow immediately while
  in-flight requests complete their terminal path with preflight still
  enforced and no fallback.
- Rollback: flag off restores pure-v1 behavior with no code change
  (v1 path untouched); code rollback is reverting the Step 7 commit. No
  migration, no state, no data to unwind.

## 8. Tests: offline and controlled real

Offline (required before any residential step): all existing gates stay
green (80 Rust, 58 Python, fmt, clippy, ER/extraction/v2 gates,
regression gate 144/144 + 23/23); `tests/mlp/test_runtime_v2.py` with HA
fakes mirroring the v1 suite — routing matrix (every cell of section
4, including all prohibitions), v2 plan success end-to-end through
preflight, stale generation via mid-flight rename, availability flip to
unavailable, denied permission blocks before first effect, timeout
propagating identically on both paths, options default-off with
per-request consult, unlinked/ambiguous abstention with no v1 call,
transport failure with no v1 call, rebuild failure, mid-chain exposure
revoke with operation count preserved, kill-switch flip mid-flight
(in-flight completes terminally, next request routes v1),
single-interpretation-call invariant, caller context preservation,
queries/ellipsis pre-routed to v1 with v2 never called, shadow
bounded to 7 probes with fixed aggregate schema and no content in logs. Controlled real (approved lab instance only): scripted
utterances from the frozen corpora against the real snapshot builder;
aggregate telemetry; manual per-domain authorization; kill-switch armed;
stale injection (rename mid-flight) and permission revocation drills
must render `stale`/`denied` with zero effects. No residential data
persisted; no utterances retained.

Objective acceptance: every offline gate green; residential shadow shows
zero false executions, zero uninvestigated divergences, correct
`stale`/`denied` drills; rollback drill (flag off) reproduces v1-only
behavior byte-identically on the scripted set.

## 9. Product decisions required

1. Routing: opt-in v2 for the single-effect slice with direct-to-v1
   pre-selection and no post-attempt fallback (recommended as specified
   in section 4), v1-only, or another policy.
2. Residential shadow instance and opt-in mechanism approval.
3. Accept that v2 abstains on ellipsis/queries (v1 covers) until a
   future bridging contract; no silent behavior change.
4. Accept candidate-free v2 abstention rendering (no clarification UX).
5. Authorize Step 7 implementation; a later decision flips ACTIVE.
   Until then everything stays available but unused.
