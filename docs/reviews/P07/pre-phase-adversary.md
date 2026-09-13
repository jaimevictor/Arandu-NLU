# P07 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `P07-ADV-CD19BC12-20260828-01`
- Input commit: `cd19bc128a52b235e30504c275aa35fd70696d25`
- Input tree: `c7bf603481967948fe0ca201596d68fb7241c5a1`
- Mode: read-only primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE`

## Baseline Facts

- `morphology.jsonl` has 29 rows, 28 unique surfaces, 29 expected analyses,
  and no row-level split.
- Those tuples equal the feature-bearing subset of the 33-entry P06 lexicon.
- The full lexicon has 32 surfaces and four featureless analyses.
- The generator emits one singleton row per feature-bearing lexicon analysis,
  not one complete surface analysis set.
- P06 exact lookup returns all equal-surface entries as a conflict and exposes
  no caller-supplied runtime artifact constructor.

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P07-A01` | Gold is created, filtered, corrected, or validated by analyzer output. Root gold only in frozen P02 specification/artifacts; enforce chronology, dependency isolation, and self-oracle mutations. |
| P0 | `P07-A02` | A coordinated manifest/package rewrite substitutes lineage or introduces a lemma, feature, or rule. Pin source, specification, generator, artifact, package, and every analysis identity; reject recomputed outer hashes. |
| P1 | `P07-A03` | Ranking, deduplication, stemming, suffix rules, or fallback collapses ambiguity or invents facts. Runtime output must be all and only immutable P06 identities; current-source inference remains absent and separately typed. |
| P1 | `P07-A04` | The unsplit 29-row artifact is mislabeled held-out, drifts version, or silently omits four featureless analyses. Freeze an explicit non-independent P07 split and report exclusions. |
| P1 | `P07-A05` | Row, surface, and analysis denominators are mixed, or confusion accounting hides missing/extra analyses. Freeze units and reconciliation invariants before scorer implementation. |
| P1 | `P07-A06` | Evaluation parsing/reporting enters the runtime graph or runtime reads files, environment, locale, time, entropy, or network. Use a separate evaluator package and prove one-way dependencies. |
| P1 | `P07-A07` | Malformed or oversized text, JSONL, sets, or reports panic, allocate without bound, truncate, or emit partial metrics. Use closed schemas, checked arithmetic, explicit limits, and whole-run invalidation. |
| P2 | `P07-A08` | Error analysis changes with input order, maps, locale, path, timestamp, or sampling. Emit canonical stable identity records with no free-form generated judgment. |
| P3 | `P07-A09` | The same-source project-authored corpus measures internal conformance only. Record this limitation and prohibit general accuracy or equivalence claims. |

## Concrete Counterexample

Two morphology rows have the same surface and one distinct expected analysis
each. P06 correctly returns both analyses together. A row-wise exact scorer
marks the correct result wrong twice; a containment scorer accepts arbitrary
extras. Gold must be grouped by surface before comparison. The scored
denominators are 28 surfaces and 29 memberships; full P06 coverage remains a
separate 32-surface/33-analysis assertion.

## Required Tests

1. Mutate oracle origin, lemma, feature, source/version/split,
   specification/generator hash, analysis identity, package, and sidecar;
   recompute outer hashes and require rejection.
2. Audit every bundled surface: returned identities equal all and only P06
   entries in canonical order and every field/lineage equals its source.
3. Reproduce the two-analysis conflict; deletion, winner selection, duplicate
   emission, and order permutation must fail.
4. Use admitted rows or opaque technical structures for missing/extra
   predictions, duplicate cases, zero predictions, denominator changes, and
   matrix reconciliation.
5. Prove evaluator exclusion through Cargo dependency and release scans;
   replay under varied working directory, locale, timezone, environment, and
   input order with byte-identical output.
6. Reject malformed UTF-8, duplicate/unknown fields, truncation, trailing
   bytes, excessive nesting/count/length/features, and exact one-over limits
   before partial output or unbounded allocation.
7. Remove or substitute admitted analysis identities and reproduce the error
   ledger byte for byte. A zero-error run emits a canonical empty ledger.

## Fail-closed Contract

- Report domain, dataset ID/version, split ID, claim scope, all input hashes,
  analyzer identity, metric-spec version, and limitations.
- Primary metric is exact sorted analysis-set equality per unique surface.
- Secondary counts are exact `TP`, `FP`, and `FN`; no fabricated true
  negatives.
- Confusion labels and matrix ordering are frozen and reconcile to all 28
  surfaces.
- Full P06 coverage is asserted separately and never blended into the
  feature-bearing metric.
- Any schema, hash, lineage, split, duplicate, limit, or reconciliation
  failure invalidates the whole run and emits no scored result.
- Unknown technical input returns no analysis; ambiguity returns every
  analysis; unsupported inference remains absent.

## Residual Risk

A P3 is admissible only when it cannot affect correctness, safety, licensing,
provenance, clean-room integrity, determinism, operation, or a requirement,
and records an owner and trigger. Corpus size and same-source dependence
qualify only while every result remains explicitly internal conformance.

## Bounded Stop

One convergence pass is one selected and dispositioned integrated tuple:
runtime contract, frozen evaluation manifest/split, scorer/error schema,
isolation boundary, and complete test portfolio. At most three passes and
three candidates are allowed. The first acceptable baseline is frozen
immediately; rounds 2 and 3 are blocker-only. Exhaustion with P0-P2 findings
requires user scope adjudication.

Primary evidence inspected: P07 and inherited requirements, `AGENTS.md`,
clean-room policy, P02 admitted source manifest/specification/generator and
morphology/lexicon artifacts, P06 package/runtime/tests, and deterministic
format and resource-limit contracts.
