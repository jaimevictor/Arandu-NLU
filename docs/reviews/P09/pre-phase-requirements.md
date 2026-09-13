# P09 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `01a04b45-aa8c-7ed2-b16b-8e55fc2d6bad`
- Input commit: `c5456be9d988633a0314f6d2a48e008a903d851c`
- Input tree: `280f9441775ab5b0dda7d16950ddcbf024ff3ef2`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE_NO_TRUE_BLOCKER`

## Mandatory Scope

P09 owns `P09-INT-001..010` and `P09-EVAL-001..002`: a closed
versioned intent schema; stable intent and slot identifiers; typed,
evidence-bearing slots; deterministic ranking and canonical output;
clarification inside a fixed ambiguity margin; abstention below a fixed
evidence threshold; pre-interpretation schema rejection; and reproducible
exact-semantic and exact-slot-value metrics for every stratum.

Applicable inherited obligations include `USR-001`, `USR-008..014`,
`USR-016`, `GLB-LING-001..003`, `GLB-INTENT-001`,
`GLB-SAFE-001..003`, `GLB-DATA-001`, `GLB-EVAL-001..002`,
`GLB-METRIC-001..005`, `GLB-DET-001..004`, `GLB-SEM-001..007`,
the applicable security and measurement rows, and all-phase Cargo, FOSS,
provenance, clean-room, lifecycle, and bounded-round contracts.

## Frozen Evidence

The sole linguistic source is
`project-authored-synthetic-ptbr-v1` version `1.0.0`, Apache-2.0
`PROJECT_AUTHORED_SYNTHETIC`, admitted only for internal conformance:

- specification SHA-256
  `f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d`;
- generator SHA-256
  `ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1`;
- train: 960 records, SHA-256
  `23d2bc8c8fcde80d1a9560d42219484bc34e9198c791ccadf5d4b56413a81b64`;
- development: 960 records, SHA-256
  `75400570ddfc7196ed982da98dcf49c4e6bda5820200a2fefd93a8ea6f049161`;
- heldout: 4,800 sealed records, SHA-256
  `1b3e3669ba3e64193b769bccf90368f571daae5b4f3d9ed88724c99bec12c6da`.

All 20 intent families have 48 train, 48 development, and 240 heldout
cases. The five frozen fail-closed suites contain 27 non-plan classes.
P09 may use train, development, applicable immutable negative oracles, and
the frozen P04-P08 runtime artifacts. Heldout remains sealed for P15
aggregate evaluation; performance records remain benchmark-only.

## Reconciliation

P02 external labels such as `HassTurnOff` do not satisfy the lowercase
namespaced `IntentId` contract. The P09 schema must map them to stable valid
internal IDs without weakening identifier validation.

P02 expected records are complete plans with resolved entity IDs and some
multi-node semantics. Entity resolution belongs to P10 and graph composition
to P11. P09 therefore requires a versioned pre-resolution projection covering
intent identity, typed unresolved slots, and checked original-byte spans. It
must not fabricate entity IDs, emit plans, or claim full-plan exactness.

The projection may only mechanically derive values and source spans from the
frozen pre-engine specification and generator. It may add no linguistic
judgment or output-derived label. A non-unique derivation is rejected rather
than guessed.

## Minimum Acceptance

1. The bounded versioned schema defines every supported intent and slot ID,
   type, constraint, threshold, and ambiguity margin.
2. Duplicate, unknown, malformed, incompatible, oversized, or dangling schema
   content fails before text interpretation.
3. Every recognized slot has a stable ID, validated closed value, and nonempty
   checked original UTF-8 span bound to the request.
4. Ranking is bounded integer score descending, then canonical semantic key.
   Ordering never breaks a semantic tie.
5. Every candidate inside the inclusive ambiguity margin is clarified; no
   threshold-qualified candidate produces abstention.
6. Equivalent input and every candidate/schema insertion permutation produce
   the same value and canonical bytes.
7. Unknown evidence creates no intent, slot, entity, graph, or plan. Production
   has no evaluator, filesystem, network, time, entropy, policy, or execution
   authority.
8. A production-isolated versioned evaluator uses development input and
   pre-engine projection only, validates all frozen identities, and reports
   exact semantics and exact slot values for every intent and slot stratum.
9. Applicable inherited validators, mutations, format, Clippy, tests, builds,
   dependency/license scans, and deterministic replay pass.

P09 adds no numerical accuracy threshold. Its results remain same-source
internal conformance only.

## Bounded Convergence

One pass is one selected and dispositioned tuple of schema and ID mapping,
evidence-bearing contract, ranking configuration, projection oracle,
evaluator boundary, and tests. At most three passes and three frozen candidate
rounds are permitted. Candidate round 1 is the first complete minimum
implementation; rounds 2 and 3 are blocker-only. Freeze the first acceptable
candidate immediately and perform no optional refinement or post-candidate
final review.

## Counterexample

An integer position with only node-wide evidence does not identify the request
bytes that supplied that slot. The P09 recognized slot must carry and validate
its own span before any later plan conversion.

Primary evidence inspected: `AGENTS.md`, clean-room policy and decisions,
P09 and inherited requirement rows, accepted ADRs, P02 manifest,
specification, generator, train/development identities, P02/P08 evidence,
and P01-P08 runtime and evaluation contracts.
