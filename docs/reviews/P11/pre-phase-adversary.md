# P11 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04b8a-b89b-7e71-b25b-3d7a8edd470c`
- Input commit: `4cffe0e1711f55c28d0bd65a0737136f2270e183`
- Input tree: `b1ff17ba23d0f3960cdb7f586486dd7b6969a59e`
- Mode: read-only independent primary-evidence inspection
- Result: `ANALYSIS_COMPLETE_WITH_HELDOUT_TAINT`

The analysis instance reported inadvertently displaying two held-out records
while locating graph strata. No held-out surface form or label is reproduced
in this report. That instance is excluded from implementation, tuning, oracle
construction, and candidate review. P11 uses only train/development,
aggregate manifest counts, and a clean implementation context.

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P11-A01` | A connective is treated as sufficient evidence for another command. Require clause-local predicate evidence and a complete closed template for every node. |
| P0 | `P11-A02` | An argument, area, device, or subject is propagated without typed evidence. Require direct argument evidence or one explicit validated share. |
| P0 | `P11-A03` | Negation is dropped, narrowed, or attached to the wrong clause. Represent supported node-local scope explicitly and abstain on unresolved or cross-clause scope. |
| P0 | `P11-A04` | A cycle, reversed order, or fully resolved semantic conflict produces a plan. Validate graph structure and operation conflicts after resolution. |
| P0 | `P11-A05` | Nodes resolve against different catalog generations. Retain one immutable snapshot and reject every mixed or stale generation. |
| P0 | `P11-A06` | A caller downgrades `NonExecutable` or `AtomicOnly` to `PartialSafe`. Derive the class inside the composer and validate structural class minima. |
| P1 | `P11-A07` | One ambiguous or failed clause is dropped while the rest executes. Invalidate the complete graph; clarification alternatives must each be complete graphs. |
| P1 | `P11-A08` | New semantic fields are silently accepted as protocol v1. Keep the P11 schema internal and preserve strict v1 bytes and rejection behavior. |
| P1 | `P11-A09` | Held-out records influence templates, thresholds, or fixes. Deny case-level held-out access and defer case-level execution to P15. |
| P2 | `P11-A10` | Construction order changes IDs, graph order, or bytes. Canonicalize all endpoint and evidence collections and test permutations. |
| P2 | `P11-A11` | Connective chains or entity collisions cause unbounded graph or alternative expansion. Enforce limits before allocation and never enumerate Cartesian entity products. |
| P3 | `P11-A12` | Diagnostics retain utterances or residential catalog values. Expose only closed redacted codes and bounded counts. |

## Required Mutations

1. Insert, delete, duplicate, and reorder conjunction and ordering cues.
2. Remove each predicate, argument, negation, relation cue, and share endpoint.
3. Move negation before, between, and after two clauses, including ambiguous
   shared scope.
4. Add self-edges, two- and three-node cycles, reversed order, duplicate edges,
   and dangling endpoints.
5. Resolve opposing operations or polarities against one entity and attempt
   to emit a plan.
6. Advance or remove the catalog between target resolutions and forge a mixed
   node generation.
7. Forge, omit, or downgrade graph execution class.
8. Introduce one alias collision or no-match target into an otherwise complete
   graph and verify no subset survives.
9. Enumerate node, relation, independence, share, slot, and evidence insertion
   orders and require byte-identical output.
10. Exercise exact and one-over node, relation, evidence, share, independent
    pair, aggregate, template, alternative, and encoded-byte limits.
11. Inject P11 fields into protocol v1 and require strict rejection while
    existing v1 fixtures remain unchanged.
12. Put privacy canaries in request and catalog values and inspect errors,
    debug output, evaluation reports, and mutation failures.

## Fail-closed Contract

Any failed clause, unsupported operation, unresolved scope, unsupported
sharing, ambiguity, contradiction, cycle, stale entity, mixed generation, or
limit breach yields zero plans. Safe-partial classification never authorizes
dropping a clause. A bounded target collision may return one complete
clarification; all other uncertainty abstains.

## Bounded Stop

One pass is one selected and dispositioned source/oracle portfolio, semantic
schema, composition route, evaluator, and mutation strategy. P11 has at most
three convergence passes and three frozen candidate rounds. The first minimum
candidate is frozen; later work is blocker-only. After the third unsuccessful
pass or candidate, stop for explicit scope adjudication instead of adding
heuristics or weakening source, safety, or correctness rules.

## Counterexample

`ligue a luz e o ventilador da sala` cannot be expanded from the connective.
The trailing area may attach to one target or both. The only valid outcomes
are complete bounded clarification or abstention, never a guessed two-node
plan or a one-node partial plan.
