# ADR-0015: Evidence-bearing intent recognition and pre-resolution evaluation

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P09-P11

## Context

P09 must recognize one typed intent, validate typed slots with checked source
evidence, rank candidates deterministically, clarify close alternatives,
abstain below an evidence threshold, and reproduce metrics by intent and slot
strata.

The P02 corpus froze 20 Home Assistant intent families and complete expected
plans before NLU implementation. Those plans contain resolved entity IDs and
some multi-node graph semantics. Entity resolution belongs to P10 and graph
composition belongs to P11. Treating the P02 plan as the P09 runtime result
would violate those ownership boundaries and invite case-identity
memorization.

The only admitted language is the Apache-2.0 P02
`PROJECT_AUTHORED_SYNTHETIC` corpus. Its split-specific templates and single
origin support internal conformance only. P09 has no independent accuracy or
generalization threshold.

## Decision

Add a production `intent-engine` crate with a closed intermediate result:

```text
RecognitionOutcome =
    Match(IntentMatch)
  | Clarification(IntentMatchSet)
  | Abstention(AbstentionReason)
```

Each `IntentMatch` contains a stable lowercase namespaced `IntentId`, bounded
integer score, checked intent evidence, and canonical `SlotBinding` values.
Every binding has a stable `SlotId`, role, occurrence index, closed typed
value, and its own checked half-open original UTF-8 byte span.

P09 values are unresolved mention text, bounded integers, booleans, or closed
enums. They are not `EntityRef`, `PlanNode`, or `Plan` values. P10 may resolve
mentions against an immutable catalog; P11 may compose successful resolved
matches into a graph.

## Schema And Ranking

Freeze a versioned train-backed schema before recognizer implementation. Each
intent maps the external P02 family label to one stable internal ID, declares
its complete slot contract, and supplies only marker lexemes present in all 48
of that intent's physical train records.

The selected minimum recognizer scores exact normalized token markers with
fixed nonnegative integer weights. A candidate exists only when every required
slot extractor succeeds and its score reaches the intent's frozen threshold.
Scores never use floating point, frequency smoothing, input position, case
identity, family identity, split identity, hashes, expected output, or package
insertion order.

Candidates sort by score descending and then by their complete canonical
semantic key. The key stabilizes output only. Every semantically distinct
candidate inside the inclusive fixed ambiguity margin is returned for
clarification; ordering cannot choose among them. No qualifying candidate
produces an evidence abstention.

Unknown tokens supply no evidence. Invalid, duplicate, contradictory,
out-of-range, missing, or foreign-source slots invalidate the candidate.
Malformed or substituted schema/package bytes disable engine construction.

## Artifact Boundary

`nlu-data` compiles the source schema into a canonical embedded package with
fixed magic and version, explicit count and byte limits, sorted records, a
strict canonical manifest, and complete source/configuration/package hashes.
The decoder rejects unknown fields or versions, malformed UTF-8, duplicate or
noncanonical records, invalid identifiers or types, bad constraints, dangling
extractor references, truncation, trailing bytes, substitutions, and exact
one-over limits before any text interpretation.

Runtime dependency direction is:

```text
nlu-core + lang-ptbr + nlu-data <- intent-engine
intent-engine + nlu-data <- intent-eval
```

`intent-engine` embeds the package and has no filesystem, network, evaluator,
policy, protocol, execution, rendering, time, entropy, or Home Assistant
authority.

## Evaluation Boundary

Freeze a P09 oracle projection before recognizer code. It mechanically maps
P02 pre-engine intent and plan fields to the P09 intent ID, slot role,
occurrence, pre-resolution typed value, and unique byte-exact source span.
Projection may reconstruct only parameters fixed by the P02 generator and may
not infer a label from recognizer output. A missing or non-unique source match
invalidates the evaluation.

The isolated `intent-eval` leaf consumes the physical development split,
projection, and production package. It reports canonical integer-only exact
semantic results for every intent and exact value/span results for every
actual slot occurrence stratum, with complete denominator reconciliation and
the internal-conformance limitation. It emits no utterance, case identity,
path, timestamp, or free-form judgment. Heldout remains sealed for P15.

## Acceptance

No favorable development score is required. Development results are evidence,
not permission to add markers after the first minimally acceptable candidate.
Acceptance requires schema and package integrity, checked slot evidence,
deterministic ranking, ambiguity and abstention behavior, evaluator isolation,
complete reproducible metrics, mutations, and inherited gates.

The first complete implementation that passes mandatory checks is frozen.
Optional refinement and a post-candidate final review are omitted under the
user's explicit completion direction.

## Consequences

- P09 cannot execute or resolve Home Assistant entities.
- Unsupported paraphrases abstain instead of being guessed.
- Entity mentions retain exact source evidence for P10.
- Repeated slot IDs remain distinct through stable role and occurrence.
- Development and future heldout scores may be low without invalidating the
  deterministic contract.
- New linguistic evidence, features, thresholds, slot kinds, or projection
  rules require a new schema/package version and a superseding ADR.

## Alternatives

1. Emit complete P02 plans in P09. Rejected because it absorbs P10/P11 and
   encourages split/case reconstruction.
2. Extend protocol v1 immediately. Rejected because the P09 intermediate value
   does not cross the adapter boundary.
3. Choose the first or lowest-ID candidate. Rejected because ordering is not
   semantic evidence.
4. Use development or heldout templates as runtime patterns. Rejected because
   development is evaluation input and heldout is sealed.
5. Add generated paraphrases. Rejected because model-generated language is
   prohibited.

## Rollback

Before acceptance, remove P09-only engine, evaluator, package, schema,
projection, validator, and ADR paths. P08 remains intact. After acceptance,
supersede this ADR and version every affected artifact instead of rewriting
accepted bytes.
