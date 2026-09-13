# P07 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `P07-ARCH-RO-CD19BC12-C7BF6034-20260828-A`
- Input commit: `cd19bc128a52b235e30504c275aa35fd70696d25`
- Input tree: `c7bf603481967948fe0ca201596d68fb7241c5a1`
- Mode: read-only independent primary-evidence inspection
- Constraints: no edits, network, sibling, internal, or Amazon sources
- Result: `PROVISIONAL_APPROACH_1_SELECTED`

## Selected Runtime

Extend `lang-ptbr`; do not change `nlu-core`, `protocol`, or P06 package
bytes and schemas.

```text
Morphology { lexicon: Lexicon }

MorphologyLookup:
  Unknown
  Unique(LexicalEvidenceAnalysis)
  Ambiguous(LexicalEvidenceSet)
```

`LexicalEvidenceAnalysis` has a private constructor and borrows the complete
P06 `LexicalAnalysis`. `LexicalEvidenceSet` exposes every canonical entry
without deduplication, ranking, or winner selection. Analysis ID, lemma,
category, sorted features, source, generator lineage, transformations, and
derivative license remain available through the borrowed P06 object.

`Morphology::bundled()` is the only constructor. It loads
`Lexicon::bundled()` and rejects construction if any exact surface exceeds
`MAX_MORPHOLOGICAL_ANALYSES_PER_TOKEN = 32`; it never truncates.
`analyze_token` uses checked `Token` and `NormalizedText` identity and exact
normalized-surface lookup.

There is deliberately no productive inference variant or rule. Empty feature
lists remain lexical evidence. Any future inference requires a superseding
ADR, an admitted rule origin, and a distinct type that cannot be represented
as lexical evidence.

Unknown input is a payload-free variant. Token/text mismatch returns
`TextError`; malformed package or excessive ambiguity prevents analyzer
construction. Runtime performs no case folding, stemming, affix rules,
repair, fuzzy matching, filesystem access, network, environment, locale,
time, entropy, or mutable global lookup.

## Evaluation Boundary

Add a non-published `morphology-eval` package with one-way dependencies:

```text
morphology-eval -> lang-ptbr -> nlu-data
```

No runtime package may depend on it or reference `morphology.jsonl`, its
manifest, case IDs, expected labels, reports, or schemas. The evaluator binary
reads only explicitly supplied root/manifest inputs, validates the complete
frozen identity before scoring, and emits one canonical report to standard
output. Test APIs may accept byte slices and injected observations for
mutations.

The P07 manifest references rather than copies:

- source `project-authored-synthetic-ptbr-v1`, version `1.0.0`;
- `data/project-authored/p02-v1/morphology.jsonl`;
- SHA-256
  `ebee221611e4cbf6206a755022d163e4c96f7eb1a42626d7032773bfb8c793dc`;
- all 29 case IDs;
- split `p07-morphology-internal-conformance-v1`;
- grouping `exact-surface-analysis-set-v1`, yielding 28 surfaces;
- claim scope `internal_conformance_only`.

This is an all-record versioned view, not independent or held-out data. It is
frozen before implementation and never used to add or repair runtime facts.

## Scoring Contract

The evaluator groups rows by exact surface before calling and scoring the
analyzer. It compares canonical sets of `(lemma, category, sorted features)`
using ordered collections.

| Output | Required baseline |
| --- | --- |
| Exact-set surface accuracy | `28/28` |
| Analysis counts | `TP=29`, `FP=0`, `FN=0` |
| Analysis precision and recall | exact integer fractions `29/29` |
| Ambiguity preservation | `1/1` |
| Confusion labels | `unknown`, `unique`, `ambiguous` |
| Confusion matrix | `[[0,0,0],[0,27,0],[0,0,1]]` |
| Error analysis | fixed taxonomy, zero baseline errors, stable source case IDs |

Every metric object carries domain, dataset ID/version, split ID, and
limitations. Reports use canonical JSON, fixed order, one final newline, and
no timestamp, absolute path, locale-derived value, entropy, or unordered map.

Required limitations state that labels and runtime lexicon share one
project-authored generator/specification, only feature-bearing analyses are
scored, four featureless entries are unscored, no expected-unknown row exists,
unknown behavior is tested structurally, and no independent accuracy,
representativeness, generalization, or product-equivalence claim is made.

Integrity, schema, provenance, duplicate, split, or resource failures emit no
report and exit nonzero. Analysis mismatches remain reportable for
deterministic error analysis but fail the P07 acceptance gate.

## Files And Contracts

- `crates/lang-ptbr/src/morphology.rs` plus exports and one limit;
- `crates/morphology-eval/Cargo.toml`, library, binary, and tests;
- `data/evaluation/p07/morphology-v1/manifest.json` and `report.json`;
- two closed morphology evaluation schemas;
- accepted ADR-0013 and ADR index entry;
- P07 validator, validator tests, evidence, report, distribution, dependency,
  and traceability updates.

No component is added without its first consumer and tests.

## Required Verification

- all 33 P06 analyses remain reachable, including four empty-feature entries;
- both repeated-surface analyses remain ordered and observable;
- an opaque technical unknown yields no lemma/features and is excluded from
  metrics;
- the 32-analysis cap accepts exactly 32 and rejects 33 in structural tests;
- duplicate, missing, substituted, malformed, oversized, or hash-mismatched
  evaluation inputs fail closed;
- record permutation and two clean runs emit byte-identical reports;
- injected admitted-identity faults reproduce matrix and error categories;
- Cargo metadata, source scans, and release graph prove evaluator exclusion;
- inherited validators, generation checks, formatting, Clippy, tests, and
  all-target builds pass.

## Counterexample

The repeated source surface has two justified analyses emitted as separate
morphology rows, while P06 correctly returns both. Row-by-row scoring falsely
marks the other required analysis as extra. Grouping by exact surface and
comparing the complete set is mandatory.

## Bounded Completion

One convergence pass is one integrated selection of runtime evidence types
and limit, evaluation dependency boundary, frozen split manifest, and
scoring/report contract. This selected approach is convergence pass 1 of at
most 3. Candidate round 1 is complete implementation; rounds 2 and 3 are
blocker-only. Freeze the first passing baseline without optional refinement.

## Rollback

Before acceptance, remove P07-only runtime, evaluator, and artifact paths.
P06 remains intact. After acceptance, supersede the ADR and create a new
dataset/split/report version instead of mutating accepted bytes.

Primary evidence inspected: P07 requirements, clean-room policy, accepted
ADRs, P02 source manifest/specification/generator/morphology/lexicon, and P06
runtime, package, tests, and validators.
