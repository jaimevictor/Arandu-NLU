# Entity Resolution Capability Ledger

Status: IMPLEMENTED_TESTED_BASELINED_NOT_ACTIVE
Owner: Arandu NLU
Scope: exact-evidence entity resolution as additive library API plus a
read-only local `/v2/resolve` endpoint, an additive snapshot builder,
mention extraction, versioned interpretation, and a tested-but-disabled
Step 7 runtime path; protocol v1 `interpret()` behavior and the Home
Assistant execution path are unchanged (v1-only in production) until
explicit activation. Steps 1-2 and 4-7 of ADR-0052 done except ACTIVE.

## Authority

This ledger supplements ADR-0050. It does not activate a new product capability,
change protocol v1, or authorize changes under `addon/engine/src/`.

Baselines A and B, their freezes, manifests, labels, and outputs remain immutable.
ADR-0016 is reference input for this preparation. It is not activated code.

## Capability states

| Capability | State | Evidence or boundary |
| --- | --- | --- |
| Exact entity ID resolution | Implemented | `addon/engine/src/resolution.rs` tier 1; unit + 21-row gold tests. |
| Explicit entity alias resolution | Implemented | Tier 2 with higher-rank suppression; unit + gold tests. |
| Area-constrained resolution | Implemented | Mandatory area/domain/capability filtering; contradiction is `no_match`. |
| Unique entity resolution | Implemented | One admissible candidate returns `resolved` only with valid evidence tier. |
| Display-name-only resolution | Excluded | A single display-name match without independent area, domain, or capability constraint returns `no_match`; it never resolves. An unconstrained equal-rank display tie abstains as `ambiguous` per the ADR-0051 tie rule. |
| Ambiguity detection | Implemented | Equal best candidates return `ambiguous` in canonical order; catalog permutation tested. |
| No-match abstention | Implemented | Unsupported, contradictory, stale, malformed, or absent evidence returns `no_match`. |
| Catalog generation binding | Implemented | Request generation must equal snapshot generation; stale is `no_match`. |
| Stable candidate ordering | Implemented | `BTreeSet` canonical ordering, output-only; permutation tests pass. |
| Span validation | Implemented | Half-open UTF-8 byte spans must equal the mention; reversed, out-of-range, misaligned, and mismatched spans are `no_match`. |
| Fuzzy or phonetic matching | Excluded | No fuzzy matching, transliteration, additional accent folding, additional case folding, or confusable folding. |
| Generic service construction | Excluded | Entity resolution does not create Home Assistant service calls. |
| Session continuation | Deferred | Requires separate clarification and session contracts. |
| Mention extraction | Implemented | `extraction.rs`: pure anchored mentions with original-UTF-8 spans, typed constraints with evidence, ellipsis inheritance, unlinked references; 30-row gold corpus; shared parser grammar. |
| Unlinked poisoning | Implemented | Any explicitly-mentioned-but-unlinked reference makes the mention unresolvable; plan atomicity propagates to no plan. Alias/entity_id precedence preserved without contradiction. |
| Versioned full interpretation | Implemented | `v2.rs` plus `POST /v2/interpret`: extraction plus resolution plus atomic plans, effects only, inherits abstention, action-as-capability constraints; 24-row gold corpus; v1 untouched. |
| ER snapshot builder | Implemented | Additive `build_er_snapshot` with SHA-256 generation over descriptors only; display/alias split; exclusions; reproducibility tests. |

## Contract lineage

- Normative preparation: `docs/adr/ADR-0051-entity-resolution-preparation.md`.
- Activation proposal (not accepted, no wiring): `docs/adr/ADR-0052-entity-resolution-activation.md`.
- Step 7 proposal (not accepted, no wiring): `docs/adr/ADR-0054-step-7-activation.md`.
- Independent specification: `evaluation/ptbr-independent/entity-resolution/spec-v1.json`.
- Synthetic catalog: `evaluation/ptbr-independent/entity-resolution/catalog-v1.json`.
- Corpus: `evaluation/ptbr-independent/entity-resolution/corpus-v1.jsonl`.
- Oracle: `evaluation/ptbr-independent/entity-resolution/oracle.py`.
- Freeze: `evaluation/ptbr-independent/entity-resolution/freeze-v4.json` (`freeze-v1.json` through `freeze-v3.json` preserved as audit history; v4 corrects three contract-violating corpus labels with unchanged 8/2/11 outcome counts, see corpus generator history).
- Pre-implementation baseline: `evaluation/ptbr-independent/entity-resolution/baselines/pre-implementation-v2.json` (`pre-implementation-v1.json` preserved; it recorded superseded `oracle.py`/`freeze.py` hashes and is not valid for the current tree).
- Post-implementation baseline: `evaluation/ptbr-independent/entity-resolution/baselines/post-implementation-v1.json` (21/21 gold conformance, benchmark, input hashes).
- Independent runner: `evaluation/ptbr-independent/entity-resolution/evaluate.py` drives preparation gates, Rust tests, and the release probe `addon/engine/examples/er_bench.rs`. It is post-implementation evidence and is intentionally outside freeze v4.
- Implementation: `addon/engine/src/resolution.rs` (`resolve_entity` plus request/outcome types, exported from `lib.rs`); one-word visibility change in `addon/engine/src/model.rs`; gold-corpus tests in `addon/engine/tests/entity_resolution.rs`.
- Step 1 (ADR-0052): `POST /v2/resolve` in `server.rs` (400 on body-parse errors, 200 on resolution outcomes, 500 on oversized outcome, v1 path byte-identical); `async_resolve` in `client.py`; `parse_v2_response` in `protocol.py` (candidates only); schemas `schemas/entity-resolution-{request,response}.schema.json`; HTTP tests `addon/engine/tests/v2_resolve.rs`; protocol/client tests `tests/mlp/test_resolve_protocol.py`; HTTP corpus validator `evaluation/ptbr-independent/entity-resolution/validate_http.py` (21/21 gold, bidirectional schema checks).
- Step 2 (ADR-0052): additive `build_er_snapshot` in `custom_components/local_nlu/catalog.py` (normative display fallback, alias/display split, SHA-256 generation over descriptors only); tests `tests/mlp/test_er_snapshot.py`. No execution wiring.
- Offline shadow tooling: `evaluation/ptbr-independent/entity-resolution/shadow_probes.py` (tier-separated probes from snapshots, aggregates-only report; synthetic data only).
- Regression gate: `evaluation/ptbr-independent/regression_gate.py` replays all Phase A (144) and Phase B (23) cases over HTTP and compares with the historical baselines without editing any freeze.
- Engine divergence record: `evaluation/ptbr-independent/entity-resolution/engine-source-divergence.json` (expected `engine_source` drift with per-file accounting; v1 behavior proven unchanged by `regression_gate.py`, not by inspection).
- Mention extraction: normative `docs/adr/ADR-0053-mention-extraction-contract.md` (PROPOSED, with three-state constraint correction); package `evaluation/ptbr-independent/mention-extraction/` (native snapshot fixture, 30-row corpus, oracle, freeze v2, honest pre-implementation v1, post-implementation v1); implementation `addon/engine/src/extraction.rs` with `normalize_with_spans` and shared parser grammar; gold tests `addon/engine/tests/extraction.rs`; evaluator `evaluate_mx.py`.
- Utterance shadow: offline probe `addon/engine/examples/mx_shadow.rs` plus runner `evaluation/ptbr-independent/mention-extraction/shadow_utterances.py` (target-set comparison, aggregates-only divergence report, synthetic data only; 0 structural errors).
- Versioned interpretation: package `evaluation/ptbr-independent/v2-interpret/` (own snapshot fixture, 24-row corpus, oracle, freeze v1, pre/post baselines); implementation `addon/engine/src/v2.rs` plus `POST /v2/interpret`; schemas `schemas/v2-interpret-{request,response}.schema.json` (snapshot subschema locked identical to ER); client `async_interpret_v2`; `parse_v2_plan`; HTTP tests; evaluator `validate_v2.py` with end-to-end loopback benchmark.
- Step 7 runtime (implemented, tested, not active): deterministic pre-selection (queries/conjunctions/unreliable input stay v1; single effect commands eligible under opt-in), terminal v2 outcomes with all post-attempt fallback prohibited, `er_row_to_allowed` adapter with validation, generation re-derivation, full preflight/execution reuse, per-request `v2_enabled`/`shadow_enabled` options (default off) with options flow, aggregates-only residential shadow (disabled), 19 dedicated runtime tests in `tests/mlp/test_runtime_v2.py`.

## Acceptance gate before implementation

1. Freeze v4 check passes without rewriting the manifest.
2. Oracle validates every corpus row before any product request.
3. Corpus contains positive, ambiguous, no-match, stale, contradiction, collision,
   permutation, malformed, and span-boundary cases.
4. Gold labels remain project-authored and independent from product output.
5. Production implementation changes no parser, protocol, or Home Assistant integration
   until this preparation is accepted and a pre-change baseline is recorded.
6. Future implementation passes all entity-resolution acceptance tests and all MLP
   regression tests.

## Implementation record (2026-09-17)

Preparation gates 1-5 passed (freeze v4 verified, oracle 21 rows, corpus
reproducible, pre-implementation-v2 recorded with empty `product_changes`).
Gate 6 passed after implementation without touching `parser.rs`, protocol v1,
or the integration:

- Rust: 31 lib tests (18 new resolution units), 21-row gold corpus test plus
  catalog-permutation test, all pre-existing MLP tests unchanged and green.
- Independent evaluation: `evaluate.py` replays all 21 gold rows through the
  release probe with zero mismatches (8 resolved, 2 ambiguous, 11 no_match).
- MLP regression: Phase A 144/144 `exact_pass` (120/120 scored) and Phase B
  23/23 `exact_pass` over HTTP with the new binary; frozen A/B baselines and
  manifests untouched.
- Benchmark: 20,000 full-corpus passes, mean ~7.9µs per case (~127k
  cases/s), peak working set ~5.2MB (Win32 external sampling).
- Post-implementation baseline recorded; capability state is
  IMPLEMENTED_TESTED_BASELINED, not ACTIVE (no protocol/integration wiring;
  activation needs its own product decision).

Known environment limits: the Windows toolchain initially shipped no
`clippy` or `rustfmt` components; both were installed from the official
toolchain during stabilization and now pass (`fmt --check` clean,
`clippy --all-targets -D warnings` clean on full recheck). The Phase A
`freeze_v2 --check` engine-source section reports drift, which is the
expected and authorized consequence of additive implementation work
(catalog, dataset, and authorship sections still verify; no manifest was
rewritten; `regression_gate.py` proves v1 behavior unchanged).

## Steps 4-6 record (2026-09-18)

- ADR-0053 security correction: mentioned-but-unlinked constraints are a
  third state (absent/valid/unlinked) and poison resolution; absence never
  substitutes interpretation failure. Dedicated negative tests at
  extraction and v2 layers.
- Mention extraction: 30-row corpus (22 extracted / 8 no_extraction),
  oracle, freeze v2, honest pre-implementation v1 (pre-code), 9 unit plus
  2 gold Rust tests, post-implementation baseline. Two genuine label
  corrections during development (rigid-ID subword suppression,
  normalization-dropped emoji), each contract-derived with versioning.
- Utterance shadow: 30 synthetic cases, 0 structural errors; 5
  resolved-on-v1-reject divergences investigated (1 new external-ID
  capability, 4 missing plan layer for Step 6); actions/ordering recorded
  not_evaluated per contract.
- Versioned interpretation: 24-row corpus (9 plan / 2 ambiguous / 13
  no_match), oracle, freeze, pre/post baselines; 9 unit plus 2 gold plus 3
  HTTP Rust tests; schemas validated bidirectionally over HTTP; end-to-end
  loopback benchmark ~3.3ms/case (~304/s), ~5.6MB peak.
- Full gate: 80 Rust tests, 34 Python tests, fmt, clippy, ER/extraction/v2
  gates, regression gate 144/144 + 23/23. States: extraction and v2 are
  IMPLEMENTED_TESTED_BASELINED, not ACTIVE (no execution wiring; Step 7
  needs explicit authorization).

## Security invariants

- No false plan from unresolved, stale, contradictory, or ambiguous evidence.
- No partial plan publication after any failed entity resolution.
- No candidate chosen because catalog order changes.
- No cross-generation candidate accepted.
- No span outside original request accepted.
- No residential catalog text persisted by this evaluation package.
- No credentials, network calls, Home Assistant execution, or generic service names.

## Measurement limits

This package measures contract conformance only. It does not claim general PT-BR
linguistic accuracy or external benchmark validity. Catalog and text are synthetic,
Apache-2.0, and authored before any future product baseline.
