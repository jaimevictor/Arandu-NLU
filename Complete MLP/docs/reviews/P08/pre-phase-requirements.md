# P08 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `01a04b1c-248f-7973-b8f2-187d3d0f1731`
- Input commit: `07317996f0c3e01eccc39f0b7ac607e284169c28`
- Input tree: `1e8c9638eb2a8b8b4a2dd85453063f9f870d2364`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE_NO_BLOCKER`

## Mandatory Scope

P08 owns these exact requirements:

| ID | Minimum obligation |
| --- | --- |
| `P08-POS-001` | Implement and document a simple deterministic baseline. |
| `P08-POS-002` | Compare one selected local deterministic approach with that baseline under one frozen scorer. |
| `P08-POS-003` | Fix the complete training configuration and seed and reproduce the artifact bytes. |
| `P08-POS-004` | Audit and report sentence, document, and origin split boundaries. |
| `P08-POS-005` | Keep the bounded runtime artifact embedded, lightweight, and offline. |
| `P08-POS-006` | Evaluate unknown inputs and unresolved ambiguity explicitly. |

Applicable inherited rows include `GLB-LING-001..003`, `GLB-DATA-001`,
`GLB-EVAL-001..002`, `GLB-METRIC-001..005`, `GLB-DET-001..004`,
`GLB-SEM-001..007`, `GLB-SEC-009..011`, `ARC-LANG-001..002`,
`NFR-MEAS-017..019`, the Cargo and test gates, and all-phase FOSS,
clean-room, dependency, lifecycle, and bounded-round contracts.

## Frozen Evidence

The only eligible POS source is
`project-authored-synthetic-ptbr-v1` version `1.0.0`, licensed Apache-2.0
and limited to same-source internal conformance:

- source manifest SHA-256
  `d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5`;
- specification SHA-256
  `f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d`;
- generator SHA-256
  `ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1`;
- POS artifact SHA-256
  `85ad18caf3ae749d3ec0135c3c01ce6d754f831d395abdc44ff1c3643a18fac8`.

The artifact contains 241 unique sentences and 1,763 tokens. Train,
development, and heldout contain 80/80/81 sentences, 8/8/9 documents, and
560/560/643 tokens. Four families are split-exclusive. Labels total ADJ 80,
ADP 240, DET 241, NOUN 477, NUM 480, VERB 241, and X 4. There are four
heldout expected-unknown tokens and one heldout ambiguity-marked sentence.
All expected POS sets are singleton sets.

Every record has the same source origin. Origin-level reporting is still
required, but cross-origin generalization is unmeasurable and cannot be
claimed.

P06/P07 provide 33 source-backed lexical analyses over 32 surfaces, including
one noun/verb conflict. P05 provides the source-backed `Number` token class.
No rejected source, Home Assistant contract text, technical fixture, project
NLU output, newly generated language, or heldout observation may add a
linguistic fact.

## Minimum Acceptance

1. Freeze a sidecar that binds the source, specification, generator, POS
   artifact, every split inventory, algorithm IDs, configuration, and seed.
2. Give the trainer physically separated train input. Development may only
   check the predeclared selection contract; heldout is available only to the
   frozen evaluator after model and scorer freeze.
3. The baseline returns all P07 lexical POS candidates, maps the P05 numeric
   class to source-backed `NUM`, and leaves every other unknown payload-free.
4. The selected approach is distinct, train-only, integer-only, local,
   deterministic, candidate-restricted, and unable to tag an unknown.
5. Missing, tied, or contradictory contextual evidence preserves the complete
   baseline ambiguity. Package order is never a linguistic decision rule.
6. Baseline and selected output use the same canonical heldout scorer. The
   comparison has no improvement threshold and cannot trigger post-heldout
   tuning.
7. Report exact token sets, sentence exactness, document exactness, the single
   origin result, unknown behavior, ambiguity behavior, reconciliation counts,
   and aggregate deterministic error categories. Every metric identifies its
   domain, dataset version, split, claim scope, and limitations.
8. Two clean-root trainings and record-order permutations emit byte-identical
   model bytes. Two evaluator roots emit the exact tracked report.
9. Production has no evaluator, expected-label, split-file, filesystem,
   network, locale, time, entropy, floating-point, or mutable-global input.
10. The embedded package is strictly decoded under explicit count and byte
    limits. Malformed, duplicate, substituted, oversized, or noncanonical
    inputs fail before output.
11. Inherited P01-P07 gates, P02 regeneration, P08 validation and mutations,
    formatting, warnings-denied Clippy, tests, all-target builds, dependency
    isolation, distribution licensing, and exact-candidate reproduction pass.

No independent PT-BR accuracy, representativeness, unseen-language,
cross-origin, or product-equivalence claim is permitted.

## Reconciliation

Strict heldout improvement is not a requirement and is rejected as an
acceptance threshold because it would make heldout results influence
selection. Development non-regression and direct structural tests establish
that the selected approach implements its frozen contract. Heldout results
are reported honestly whether better, equal, or worse.

The user waived the post-candidate final phase review after mandatory gates
pass. Pre-phase independent analysis, immutable candidate reproduction, and
all mandatory automated evidence remain required.

## Bounded Convergence

One convergence pass is one selected and dispositioned integrated tuple:
baseline, contextual contract, split chronology, training configuration,
runtime artifact boundary, scorer, and tests. P08 permits at most three
passes and three frozen candidate rounds. Candidate round 1 is the complete
minimum implementation; rounds 2 and 3 are blocker-only. Freeze the first
minimum candidate immediately. Unused capacity is not refinement budget.

After three unsuccessful passes, or an open P0-P2 after round three, stop and
request explicit scope adjudication.

## Counterexample

Choosing the first P06 analysis tags both occurrences of an ambiguous surface
identically and turns package order into an undocumented classifier. P08 must
make token-specific contextual decisions while retaining every candidate
when the admitted context is insufficient.

Primary evidence inspected: `AGENTS.md`, clean-room policy and decisions,
P08 and inherited requirement rows, accepted ADRs, P02 source manifest,
specification, generator and POS artifact, and P05-P07 runtime and evaluation
contracts.
