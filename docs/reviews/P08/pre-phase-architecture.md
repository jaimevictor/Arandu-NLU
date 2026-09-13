# P08 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04b1c-2d17-76f2-ab52-c4693014e6b4`
- Input commit: `07317996f0c3e01eccc39f0b7ac607e284169c28`
- Input tree: `1e8c9638eb2a8b8b4a2dd85453063f9f870d2364`
- Mode: read-only independent primary-evidence inspection
- Constraints: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SELECTED`

## Selected Runtime

Extend `lang-ptbr` with a deterministic evidence lattice:

```text
PosLookup =
  Unknown
  | Unique(PosEvidence)
  | Ambiguous(PosEvidenceSet)
```

The documented baseline derives candidates independently for each token.
P07 lexical analyses supply lexical POS evidence. A token that P05 classifies
as `Number` supplies `NUM` evidence because that mapping occurs throughout
the admitted train split. Everything else remains payload-free `Unknown`.

The selected approach adds conservative adjacent-context narrowing. Its
train-only model is a set of observed adjacent POS transitions, including
sentence boundaries. For an ambiguous token, each original adjacent singleton
may support candidates through one transition. Exactly one supported
candidate permits narrowing. No support, support for multiple candidates,
conflicting sides, an unknown neighbor, or an ambiguous neighbor preserves
the complete original candidate set.

Evaluation is non-cascading: a selected result cannot become context for
another token in the same sentence. The rule is therefore order-independent.
It never changes a unique candidate and never assigns any POS to an unknown.
There are no probabilities, weighted counts, smoothing, position features,
sentence identities, affix rules, repairs, or winner tie-breaks.

## Model Boundary

Extend `nlu-data` with a strict deterministic POS transition package compiler
and decoder. The canonical binary starts with `NLUPOS\0`, has one version,
and stores sorted unique transition records. Its canonical JSON manifest binds
the source, specification, generator, original POS artifact, physically
separated train input, train case/document/origin digests, compiler and
configuration identities, fixed seed `0`, package bytes, and package hash.
The algorithm records that no randomness is used despite the fixed seed.

Limits are eight supported tags, 100 transitions including boundaries, and
16 KiB each for package and manifest. Compilation rejects unsupported labels,
duplicate identities, malformed spans, mixed splits, and one-over limits.

`lang-ptbr` embeds package and manifest bytes and decodes them during
construction. It performs no runtime filesystem or network access.

## Access And Evaluation Boundary

Mechanically derived, byte-preserving train, development, and heldout slices
are frozen before model implementation. Their manifest proves a complete,
disjoint partition of the original artifact. The trainer can open only train.
Development checks the predeclared no-regression selection contract. The
heldout evaluator runs only after algorithm, model, and metric identities are
fixed.

Add one non-published `pos-eval` leaf:

```text
pos-eval -> lang-ptbr -> nlu-data
pos-eval -> nlu-data
```

It provides separate training and evaluation binaries. No production crate
depends on it or references POS oracle paths, case identities, expected
labels, evaluator schemas, or reports.

The evaluator compares independent baseline candidates and selected
contextual results with one scorer. It emits canonical integer-only exact-set
token metrics, sentence/document/origin exactness, unknown and ambiguity
metrics, reconciliation counts, baseline delta, and aggregate error
categories. It emits no heldout utterance, token text, or free-form judgment.

Split audits use sentence hashes and document IDs. Family is reported but not
treated as independent leakage proof because the generator assigned
split-specific family IDs. Origin reporting records the one shared source and
explicitly disclaims origin-disjoint evaluation.

## Required Files

- `crates/nlu-data/src/pos.rs` and compiler/decoder tests;
- `crates/lang-ptbr/src/pos.rs`, exports, and runtime tests;
- one `crates/pos-eval` training/evaluation leaf with CLI tests;
- P08 split, package, manifest, heldout report, and closed schemas;
- accepted ADR-0014, P08 validator and mutation suite;
- evidence, distribution, dependency, requirement, and phase updates.

Every new component has an immediate consumer and tests.

## Required Verification

- train-only compilation is invariant to record order and byte-identical in
  two roots;
- development or heldout bytes cannot enter or alter the model;
- model records contain no text, case, document, family, split, text hash, or
  record-position key;
- baseline exact candidates retain all P07 evidence and source-backed numbers;
- one-sided unique context can narrow a conflict;
- absent and contradictory contexts retain complete canonical ambiguity;
- unknown input remains payload-free and acts as a context barrier;
- selected outputs are non-cascading and token-order independent;
- invalid UTF-8, spans, tags, duplicates, sizes, counts, hashes, paths, and
  trailing bytes fail closed;
- Cargo graph and source scans prove evaluator and oracle exclusion;
- inherited validators, P02 regeneration, formatting, Clippy, tests, builds,
  P08 mutations, two-root report replay, and exact candidate reproduction pass.

Heldout comparison has no success threshold beyond internally consistent,
reproducible reporting. This prevents evaluation-driven tuning.

## Bounded Completion

This selected architecture is convergence pass 1 of at most 3. Candidate
round 1 is the complete implementation; later rounds are blocker-only. Freeze
the first passing minimum and perform no optional refinement or post-candidate
final review.

## Counterexample

In a sentence containing the same noun/verb surface twice, selecting package
order necessarily emits the same POS twice. The frozen adjacent evidence can
support one occurrence while leaving the other tied. Non-cascading selection
prevents that first decision from manufacturing evidence for the second.

## Rollback

Before acceptance, remove P08-only runtime, data-package, evaluator, schema,
validator, and ADR paths. P07 remains intact. After acceptance, supersede the
ADR and version every changed artifact instead of rewriting accepted bytes.

Primary evidence inspected: P08 requirements, clean-room policy, accepted
ADRs, P02 source manifest/specification/generator/POS artifact, and P05-P07
runtime, package, evaluator, and validator contracts.
