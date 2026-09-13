# ADR-0017: Evidence-bound semantic plan composition

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P11-P15

## Context

P09 returns one whole-request intent match with checked predicate and slot
spans. P10 resolves entity mentions against one immutable catalog generation.
The existing core `Plan` stores typed nodes, slots, evidence, and acyclic
`Precedes` or `Requires` relations, but it cannot distinguish predicate,
argument, or negation evidence and cannot express independence, sharing, or
graph execution class.

P02 train and development contain single, parallel-pair, and ordered-pair
graphs. Its admitted suites cover conflict and coordination scope but no
multi-intent negation stratum. The user explicitly authorized the best bounded
workaround, including a project-created source when necessary.

## Decision

### Core Contract

Add a dependency-free `ComposedPlan` around the existing `Plan`.
`ComposedPlan` carries one semantic clause record per node, typed evidence
atoms, polarity, evidence-bearing directional relations, explicit independent
pairs, typed argument shares, and graph execution class.

Every node requires predicate evidence. Every slot requires direct argument
evidence or exactly one inbound share. A negated node requires negation
evidence. Relation and share endpoints must exist, share values must be equal,
share destinations must be unique, and relation/share graphs must be acyclic.
All spans must belong to the same original request.

Collections are bounded and canonically ordered. A multi-node graph must
explicitly disposition node pairs as related or independent. Negation cannot
be classified below `NonExecutable`; independence cannot be classified below
`AtomicOnly`.

### Composer Boundary

Add one authority-free production crate:

```text
nlu-core + intent-engine + ha-catalog + lang-ptbr <- plan-engine
```

The composer accepts one P09 match and one retained P10 snapshot. A bounded
closed table keyed by `IntentId` maps admitted slot occurrences and exact
train-admitted cues to nodes, relations, shares, polarity, and execution
class. A connective alone never creates a node. There is no generic clause
splitter, probabilistic search, implicit propagation, or Cartesian expansion
of target ambiguity.

Every mention resolves against the same catalog generation. Any failed,
ambiguous, stale, contradictory, unsupported, or incomplete clause
invalidates the complete graph. One bounded P10 target collision may be
returned as clarification; no partial plan is returned.

The admitted graph shapes are one affirmed node, the independent two-target
turn-on graph, the ordered timer start/status graph with explicit timer
sharing, and the frozen node-local negation graphs. Fully resolved operation
conflicts abstain rather than becoming `NonExecutable`.

The graph class is descriptive, not execution authority:

- `PartialSafe`: one affirmed node or the admitted ordered timer graph;
- `AtomicOnly`: the admitted independent parallel action graph;
- `NonExecutable`: any represented negated graph.

P13 and P14 still require risk policy, authorization, capability support,
adapter mapping, and execution-time revalidation.

### Canonical Encoding And Protocol

The internal `p11-semantic-plan-v1` encoding uses fixed field order and
contains closed tags, typed IDs and values, generations, and half-open byte
spans. It contains no source text, unordered map, float, timestamp, path,
random identifier, or locale-dependent value. Encoded output is capped at
65,536 bytes.

Protocol v1 remains byte-identical and continues to decode the existing
`Plan`. P11 semantic fields are not added to v1. A later phase may define
protocol v2 while retaining v1 decoding.

### Evaluation And Negation Source

Add production-isolated `plan-eval`. Before composer implementation, freeze a
mechanical P02 train/development projection, deterministic generation-1
catalog projection, and a separate minimal
`PROJECT_AUTHORED_SYNTHETIC` multi-intent negation supplement.

The supplement is Apache-2.0, versioned, reproducible, fixed before P11
composer code, and restricted to explicit node-local and ambiguous negation
scope. Its expected semantics are generator-defined and never derived from
this project's NLU output. It is internal conformance data only, not an
external source, independent accuracy evidence, human validation, a P02
refreeze, or authorization to inspect held-out data.

Evaluation reports exact outcome and graph match by split and stratum,
including values, typed evidence, polarity, relations, independence, shares,
class, and canonical bytes. No P11 accuracy threshold is introduced.

## Acceptance

Acceptance requires:

- every `P11-MULTI-001..015` requirement and `GLB-INTENT-002` passing;
- deterministic supplement generation and source-lineage validation;
- graph invariant, conflict, stale-generation, ambiguity, privacy, canonical
  permutation, exact one-over, and connective counterexample tests;
- exact train/development metric reconciliation without held-out access;
- unchanged protocol-v1 fixtures and decoding;
- focused tests, strict clippy, locked build, source/license gates, and
  inherited regressions; and
- all mandatory reviewers passing one immutable subject with no open P0-P2.

The first complete minimum implementation is frozen. P11 has at most three
convergence passes and three candidate rounds; later rounds are blocker-only
and unused rounds do not permit refinement.

## Consequences

- Graph semantics remain auditable back to original request bytes.
- Coordination does not become evidence merely because a conjunction exists.
- Supported sharing and negation are explicit rather than inferred by an
  adapter.
- Protocol v1 remains stable.
- Entity synchronization, session state, policy, execution, and response
  rendering remain outside P11.
- Internal conformance limitations remain visible in every metric.

## Alternatives

1. Extend protocol v1 in place. Rejected because v1 is strict and existing
   decoders must remain supported.
2. Split on conjunctions and infer missing predicates or arguments. Rejected
   because punctuation and connectives do not establish scope or intent.
3. Return an unambiguous subset when another clause fails. Rejected because it
   changes requested semantics and can cause unsafe partial execution.
4. Treat graph class as caller input. Rejected because a downgrade could
   authorize routing that the graph structure forbids.
5. Claim the P11 supplement as independent evaluation. Rejected because it is
   project-authored internal conformance material.

## Rollback

Before P11 acceptance, remove the P11 supplement, projection, two P11 crates,
`ComposedPlan`, and this ADR; P09, P10, protocol v1, and P02 remain unchanged.
After acceptance, supersede this ADR and version affected internal or wire
schemas rather than rewriting accepted artifacts.
