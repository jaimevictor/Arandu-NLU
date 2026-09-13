# ADR-0013: Lexical-evidence morphology and isolated evaluation

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-28
- Owners: P07-P09

## Context

P07 must return every justified morphological analysis, preserve ambiguity,
keep unknown facts unknown, and reproduce a versioned evaluation without
letting evaluation labels influence runtime behavior.

The only eligible linguistic evidence is the P02
`project-authored-synthetic-ptbr-v1` source already compiled into the P06
lexicon package. Its morphology artifact contains 29 feature-bearing analyses
over 28 exact surfaces. The P06 package also contains four source analyses
with empty feature lists, so production coverage is 33 analyses over 32
surfaces. The evaluation is same-source internal conformance, not independent
accuracy, representativeness, or unseen-form generalization.

## Decision

Extend `lang-ptbr` with a lexical-evidence-only morphology API:

```text
MorphologyLookup =
  Unknown
  | Unique(LexicalEvidenceAnalysis)
  | Ambiguous(LexicalEvidenceSet)
```

`Morphology::bundled` is the only constructor. It wraps the immutable P06
lexicon and returns all exact-surface entries in package order. Borrowed
`LexicalEvidenceAnalysis` values retain the complete P06 source and generation
lineage. There is no inference, stemming, repair, case folding, ranking,
deduplication, or winner selection. Unknown input has no analysis payload.
Construction rejects any surface with more than 32 analyses rather than
truncating it.

Add the non-published `morphology-eval` package as an evaluation-only leaf.
Production crates cannot depend on it, and `lang-ptbr` cannot read evaluation
files. The evaluator receives an explicit repository root and sidecar
manifest, validates pinned identities before scoring, groups oracle rows by
exact surface, and compares complete ordered analysis sets.

The sidecar identifies dataset version `1.0.0`, split
`p07-morphology-internal-conformance-v1`, all 29 case identities, source and
artifact hashes, the P06 package hash, grouping and metric specifications,
fixed confusion labels, fixed error categories, and limitations. It describes
an all-record same-source view and never claims a held-out or independent
split.

The report is canonical JSON with one final newline. Every metric records its
domain, dataset ID and version, split ID, claim scope, and limitations.
Fractions remain exact integer numerator/denominator pairs. Confusion labels
are `unknown`, `unique`, and `ambiguous`; error records use only
`missing_analysis`, `unexpected_analysis`, and `cardinality_mismatch`.
Malformed, oversized, duplicate, unpinned, or inconsistent inputs produce no
report. Prediction mismatches produce a deterministic report but fail the P07
acceptance gate.

## Consequences

- Runtime morphology adds no linguistic fact beyond P06.
- All 33 P06 analyses remain reachable; the 29-row evaluation scores only the
  documented feature-bearing subset.
- The baseline can establish exact internal source replay only.
- A productive rule, another source, a changed split, or a changed metric
  requires a new admitted identity and a superseding decision.
- The evaluator may use filesystem access only for its explicit root inputs;
  runtime packages remain filesystem-, network-, environment-, time-, and
  entropy-independent.

## Alternatives

1. Add inferred inflections. Rejected because no admitted rule source supports
   them.
2. Score each morphology row independently. Rejected because the repeated
   surface has two justified analyses and must be compared as one set.
3. Embed the oracle in `lang-ptbr`. Rejected because it would make evaluation
   data reachable from production behavior.
4. Author new labels for broader metrics. Rejected because model-generated or
   otherwise unprovenanced language cannot become project gold. Structural
   technical fixtures remain permitted only outside linguistic metrics.

## Rollback

Before acceptance, remove the P07 morphology module, evaluator package,
sidecar, report, schemas, validator, and this ADR index entry. P06 remains
unchanged. After acceptance, supersede this ADR and version every changed
artifact instead of rewriting accepted bytes.
