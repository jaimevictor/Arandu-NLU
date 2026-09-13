# P11 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04b8a-b19b-75e1-a335-a254fba24a4e`
- Input commit: `4cffe0e1711f55c28d0bd65a0737136f2270e183`
- Input tree: `b1ff17ba23d0f3960cdb7f586486dd7b6969a59e`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SELECTED`

## Selected Boundary

Add a dependency-free `nlu-core::ComposedPlan` that wraps the existing
generation-bound `Plan`, plus two crates:

```text
nlu-core + intent-engine + ha-catalog + lang-ptbr <- plan-engine
plan-engine + nlu-data + serde + serde_json <- plan-eval
```

`plan-engine` is production code with no protocol, filesystem, network, time,
entropy, session, policy, adapter, execution, or rendering dependency.
`plan-eval` is evaluation-only and cannot become a production dependency.

Protocol v1 continues to encode and decode the existing `Plan` exactly. P11
adds an internal schema named `p11-semantic-plan-v1`; a later protocol version
may transport it without weakening v1.

## Semantic Graph

`ComposedPlan` adds:

- one `ClauseSemantics` per node;
- `Predicate`, `Argument(slot)`, and `Negation` evidence atoms;
- `Affirmed` or `Negated` polarity;
- checked evidence for every directional relation;
- explicit unordered independent node pairs;
- explicit typed argument-share edges; and
- `PartialSafe`, `AtomicOnly`, or `NonExecutable` graph class.

Every node has predicate evidence. Every slot has direct argument evidence or
exactly one inbound share. A negated node has explicit negation evidence.
Every relation has source evidence. Share endpoints exist, carry equal values,
have a unique destination, and form no cycle. Evidence spans belong to the
same original request.

The wrapper canonicalizes every collection. Multi-node pairs must be
explicitly related or independent. Negation requires `NonExecutable`;
independence requires at least `AtomicOnly`. The composer derives the exact
class from a closed template and callers cannot downgrade those minima.

Semantic operation conflicts are checked after entity resolution. A fully
resolved conflict abstains as ambiguous; it is not represented as a
non-executable graph. An unresolved clause, scope, share, or target invalidates
the whole graph.

## Composition

`plan-engine` accepts one complete P09 `IntentMatch`, the original
`RequestText`, and one retained P10 `CatalogSnapshot`. It uses a bounded,
versioned table keyed by `IntentId`.

The table maps admitted slot occurrences to nodes and declares exact
train-admitted predicate, ordering, negation, and sharing cues. A connective
never creates a node. No generic clause splitter, beam search, Cartesian
entity product, implicit argument propagation, or session state exists.

The supported graph shapes are:

- one affirmed node, classified `PartialSafe`;
- the admitted two-target turn-on template, with explicit independence and
  `AtomicOnly`;
- the admitted timer start/status template, with `Precedes`, one timer share,
  and `PartialSafe`; and
- the frozen P11 node-local negation templates, with explicit polarity,
  independence, and `NonExecutable`.

P10 resolution runs for every mention against the same snapshot generation.
One ambiguous target returns the bounded P10 clarification. No match, mixed
generation, unsupported propagation, or more than one ambiguous target
abstains. No unambiguous subset is returned.

## Canonical Bytes

The internal encoding uses fixed field order:

`schema_version`, `catalog_generation`, `execution_class`, `nodes`,
`relations`, `independent_pairs`, `argument_shares`.

Nodes sort by ID; slots by ID; evidence by kind, slot, start, and end;
relations by endpoint and kind; independent endpoints use lower ID first; and
shares sort by both endpoint tuples. The encoding contains only closed tags,
IDs, integers, booleans, entity generation, and byte spans. It contains no
source text, map, float, timestamp, path, locale-dependent value, or random
identifier and is capped at 65,536 bytes.

## Evaluation

Before composer implementation, freeze:

1. a mechanical projection of P02 train/development graph labels;
2. explicit independence for parallel pairs;
3. explicit timer argument sharing and ordering evidence for ordered pairs;
4. a deterministic generation-1 catalog projection; and
5. the separate P11 multi-intent negation supplement authorized by the user.

`plan-eval` reports exact outcome and exact graph match, including node values,
typed evidence, polarity, relations, independence, sharing, class, and
canonical bytes. It evaluates only train and development. The engine output
never establishes catalog values or gold labels.

## Limits And Verification

Retain the existing request, node, relation, slot, evidence, and aggregate
limits. Add maxima of 256 shares, 256 independent pairs, 64 relation/share
evidence spans, 32 composition templates, and 65,536 canonical bytes.

Tests cover insertion permutations, byte snapshots, foreign spans, missing
predicate/argument/negation evidence, dangling and cyclic relations/shares,
class downgrades, contradiction, stale catalogs, entity ambiguity, connective
counterexamples, supported graph shapes, exact one-over limits, evaluation
reconciliation, held-out denial, privacy canaries, and unchanged protocol-v1
fixtures.

## Bounded Completion And Rollback

The selected source, schema, composer, evaluator, and test portfolio is
convergence pass 1 of at most 3. Candidate round 1 freezes the first complete
minimum. Unused passes and rounds are not refinement entitlement.

Before acceptance, remove only P11 additions and return to the P10 baseline.
After acceptance, supersede this architecture and version affected internal
or wire schemas; do not rewrite accepted bytes or remove protocol-v1 decoding.

