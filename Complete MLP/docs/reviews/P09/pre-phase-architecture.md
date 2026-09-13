# P09 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04b45-b261-75c0-9a3f-1f8df237c9cf`
- Input commit: `c5456be9d988633a0314f6d2a48e008a903d851c`
- Input tree: `280f9441775ab5b0dda7d16950ddcbf024ff3ef2`
- Mode: read-only independent primary-evidence inspection
- Constraints: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SELECTED`

## Selected Boundary

Add one production `intent-engine` crate and one isolated `intent-eval` leaf.
Extend `nlu-data` with strict intent package compilation and decoding while
reusing `lang-ptbr` for P04-P08 text evidence and `nlu-core` for stable IDs
and checked original UTF-8 spans:

```text
nlu-core <- lang-ptbr
nlu-core + lang-ptbr + nlu-data <- intent-engine
intent-engine + nlu-data <- intent-eval
```

Production does not depend on `intent-eval`. `intent-engine` has no protocol,
policy, execution, rendering, filesystem, network, or Home Assistant
authority.

The runtime contract is:

```text
RecognitionOutcome =
    Match(IntentMatch)
  | Clarification([IntentMatch])
  | Abstention(AbstentionReason)
```

`IntentMatch` contains a stable `IntentId`, bounded integer score, checked
intent evidence, and canonically ordered `SlotBinding` values. Every binding
contains stable `SlotId`, stable role, occurrence index, closed typed value,
and a nonempty checked original-byte span. P09 values are unresolved text or
entity mentions, bounded integers, booleans, and closed enums. Entity
resolution, operations, graph nodes, and plans remain out of scope.

## Schema And Package

Freeze a closed schema and embedded package under `data/intents/p09/`.
The canonical manifest binds schema, compiler, algorithm, configuration,
source manifest, P02 specification, generator, physical train input, intent
and slot inventories, thresholds, package size/hash, and
`randomness_used: false`.

The package has fixed magic and version, explicit bounds, sorted records, and
canonical framing. Construction validates the whole package before accepting
request text. Unknown versions or fields, invalid IDs or types, duplicates,
bad ranges/cardinalities, noncanonical order, truncation, trailing bytes,
substitution, and exact one-over limits reject construction. There is no
fallback schema.

Only admitted P02 train records may contribute runtime linguistic patterns.
Development and applicable fail-closed suites are evaluation inputs. No
heldout row, template, hash, case identity, expected label, or project output
may influence runtime artifacts.

## Deterministic Recognition

1. Normalize and tokenize through the existing checked PT-BR pipeline.
2. Generate only package-backed candidates.
3. Validate every required slot, role, occurrence, type, range, cardinality,
   contradiction, and original-byte evidence span.
4. Compute one checked bounded integer score from the frozen evidence tuple.
5. Sort by score descending and canonical complete-hypothesis key.
6. Remove candidates below the fixed evidence threshold.
7. Abstain when none remains.
8. Clarify every semantically distinct candidate inside the inclusive margin.
9. Match only when the leading candidate is outside that margin.

Canonical IDs stabilize serialization but never break a semantic tie.
Candidate and schema insertion order cannot affect bytes or outcomes.

## Projection And Evaluation

Before recognizer implementation, freeze a P09 oracle projection derived only
from P02 pre-engine semantics. It defines intent mapping, non-plan mapping,
slot ID/role/occurrence mapping, typed pre-resolution values, exact source
spans, and repeated-slot flattening. Ambiguous derivations fail closed; output
can never establish gold.

`intent-eval` consumes only the pinned development projection, applicable
negative suites, and production package. It emits canonical aggregate JSON
without utterances, paths, timestamps, random IDs, or free-form judgments.
Metrics include exact semantic outcomes by intent, exact typed values by
actual slot occurrence stratum, exact spans, clarification, abstention, errors,
and complete denominator reconciliation. Every metric records domain, dataset
ID/version, split, claim scope, identities, and limitations.

## Required Verification

- malformed schema/package/version/field/ID/type/range/cardinality mutations;
- package truncation, trailing bytes, reordering, substitution, and one-over
  resource limits;
- train record and candidate insertion permutations produce identical bytes;
- checked multibyte spans and invalid-boundary negatives;
- below-threshold abstention and exact/inside-margin clarification;
- unknown and contradictory inputs fail closed;
- integer overflow and excessive-candidate rejection;
- intent, slot, value, span, and denominator metric mutations;
- two isolated evaluations emit the exact tracked report;
- production dependency/source/archive scans exclude evaluator and oracle;
- inherited P01-P08 gates, P02 regeneration, formatting, warnings-denied
  Clippy, tests, builds, and exact-candidate reproduction.

## Bounded Completion

This selected architecture is convergence pass 1 of at most 3. Candidate
round 1 is the complete minimum implementation; later rounds are blocker-only.
Freeze the first passing minimum and perform no optional refinement or
post-candidate final review.

## Counterexample

Two validated cancellation candidates with equal integer score remain
ambiguous. Reversing schema order must emit the same clarification, and a
lexicographic intent ID must never select a winner.

## Rollback

Before acceptance, remove the two crates, `nlu-data` intent module, workspace
entries, P09 schemas, and artifacts. Existing protocol and P02-P08 contracts
remain unchanged. After acceptance, supersede schema and package versions
instead of rewriting accepted bytes.

Primary evidence inspected: P09 requirements, clean-room policy, accepted
ADRs, P02 manifest/specification/generator and train/development contracts,
and P01-P08 runtime, package, evaluator, and validator boundaries.
