# P09 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04b45-bb36-7b22-a3ab-b3d7b8e4abe9`
- Input commit: `c5456be9d988633a0314f6d2a48e008a903d851c`
- Input tree: `280f9441775ab5b0dda7d16950ddcbf024ff3ef2`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE`

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P09-A01` | Heldout rows, templates, hashes, identities, labels, predictions, or project output influence rules, thresholds, selection, debugging, or gold. Keep runtime compilation physically train-only and the P09 evaluator development-only; heldout remains sealed for P15 aggregate access. |
| P0 | `P09-A02` | Rejected, unprovenanced, technical-fixture, or newly model-generated language enters runtime or evaluation. Accept only the provenance-bound P02 corpus and previously admitted packages. |
| P1 | `P09-A03` | A full-plan oracle absorbs P10 entity resolution or P11 graph construction. Freeze a P09 pre-resolution projection before recognizer code. |
| P1 | `P09-A04` | A slot lacks its own checked original-byte evidence. Use a closed P09 match type rather than node-wide evidence or protocol assumptions. |
| P1 | `P09-A05` | Text, case, hash, family, split, position, or expected-result lookup is presented as recognition. Forbid these fields from production artifacts and preserve the internal-conformance limitation. |
| P1 | `P09-A06` | Insertion order, unordered maps, floating point, or an ID tie-break collapses ambiguity. Use bounded integers and canonical complete-hypothesis ordering after applying the ambiguity margin. |
| P1 | `P09-A07` | Unknown, contradictory, duplicate, or ill-typed evidence emits a partial or first-match result. Reject the hypothesis or return canonical clarification/abstention. |
| P1 | `P09-A08` | Normalized matching produces incorrect original UTF-8 spans. Map through checked normalization ownership and reject invalid boundaries or ownership. |
| P1 | `P09-A09` | Evaluator code, expected labels, corpus paths, or filesystem access becomes runtime reachable. Preserve a leaf evaluator and enforce Cargo, source, and archive scans. |
| P2 | `P09-A10` | Malformed or oversized schema/package input panics, truncates, or yields partial output. Reject duplicate/unknown fields, invalid UTF-8, bad types, bad spans, trailing bytes, and exact one-over limits before interpretation. |
| P2 | `P09-A11` | Metrics use only the scalar primary slot kind and omit actual repeated slots. Enumerate every projected occurrence and exactly reconcile cases, slots, outcomes, false positives, and false negatives. |
| P3 | `P09-A12` | One templatic project-authored source overstates practical accuracy. Report only same-source internal conformance. |

## Required Mutations

1. Inject heldout bytes or identities into compiler/model/runtime inputs.
2. Substitute recognizer output for expected projection or modify gold after
   predictions.
3. Mutate source, authorization, license, generator/specification, split,
   projection, package, or manifest identities, including coordinated outer
   hashes.
4. Exercise unknown schema versions and fields, duplicate IDs/roles/slots,
   wrong value kinds, missing evidence, bad ranges, and cardinality failures.
5. Permute equal-score hypotheses and slot/schema order; require identical
   bytes and complete margin alternatives.
6. Insert multibyte technical canaries before evidence; require exact original
   spans or rejection.
7. Replay applicable unknown, ambiguity, contradiction, and explicit-negative
   cases; require no invented or partial match.
8. Add evaluator imports, metric labels, corpus paths, or expected values to
   production; require dependency and archive rejection.
9. Exercise malformed UTF-8/JSON, duplicate keys, nesting/count/byte limits,
   truncation, trailing bytes, invalid spans, and each exact one-over limit.
10. Delete, duplicate, or reassign a case or slot occurrence and alter a
    numerator or denominator; require reconciliation failure.
11. Rebuild under reordered inputs and varied roots/environment; require
    byte-identical package and report.

## Fail-closed Contract

- Runtime candidates originate only from the validated train-backed package.
- Unknown evidence creates no semantic payload.
- Every slot is closed, typed, bounded, source-owned, and schema-valid.
- Canonical ordering never chooses among candidates inside the margin.
- Any schema, integrity, provenance, limit, or reconciliation failure
  invalidates the whole construction or evaluation.
- Development mismatches are aggregate evidence and cannot authorize new
  linguistic rules after the first minimum candidate.

## Bounded Stop

One convergence pass is one selected tuple of versioned schema, pre-resolution
projection, runtime recognizer, train/development isolation, evaluator,
metrics, provenance boundary, limits, and mutations. At most three passes and
three candidate rounds are allowed. Freeze the first acceptable baseline;
rounds 2 and 3 are blocker-only.

After three unsuccessful passes, or with any P0-P2 after candidate round 3,
stop for explicit scope adjudication rather than inspecting heldout,
fabricating language, or weakening provenance.

## Counterexample

Equal-score technical hypotheses `fixture_tecnica:intent_a` and
`fixture_tecnica:intent_b` supplied in both orders must produce one identical
clarification containing both. Neither insertion order nor ID order may select
one.

Primary evidence inspected: P09 and inherited requirements, `AGENTS.md`,
clean-room policy, P02 manifest/specification/generator and split contracts,
P01 core values and spans, P08 isolation precedent, protocol boundaries, and
existing validation evidence.
