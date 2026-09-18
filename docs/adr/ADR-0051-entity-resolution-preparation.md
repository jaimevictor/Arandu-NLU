# ADR-0051: Entity resolution preparation contract

- Status: `PREPARED_NOT_IMPLEMENTED`
- Date: 2026-09-17
- Supersedes: none
- Scope: contract preparation only

## Decision

Prepare, but do not activate, an exact-evidence entity-resolution capability for a
future post-MLP increment. This ADR does not change ADR-0050, protocol v1, the active
parser, or the Home Assistant integration.

A future implementation must resolve one utterance against one immutable catalog
snapshot and one explicit generation. It returns one of:

- `resolved`: exactly one best candidate;
- `ambiguous`: multiple equal best candidates;
- `no_match`: no admissible candidate or invalid evidence.

It must never return a winner by catalog order, score tie, or fallback heuristic.

## Input contract

A future request contains:

- original UTF-8 utterance;
- immutable catalog snapshot;
- catalog generation;
- one entity mention;
- optional typed constraints, including area and domain;
- checked half-open byte spans into the original utterance.

Every supplied constraint is mandatory. Missing or contradictory constraints fail
closed. Catalog generation mismatch is stale input and returns `no_match`.

## Catalog records

Each entity has:

- stable `registry_id`;
- dotted `entity_id`;
- `domain`;
- optional `area_id`;
- explicit aliases;
- display name;
- supported capabilities.

Stable registry identity and dotted entity ID remain separate. Resolution output uses
stable registry ID. Catalog records must be enabled and exposed before entering a
future executable catalog.

## Matching precedence

Matching uses exact comparison after the already contracted Unicode normalization.
The active `normalize.rs` contract performs Unicode decomposition, removes combining marks,
converts letters to lowercase, and canonicalizes punctuation and whitespace. Those steps
remain the only case and diacritic normalization available to this capability. This ADR
adds no further folding, transliteration, confusable handling, or fuzzy behavior.

Precedence is strict:

1. exact external dotted `entity_id`;
2. exact explicit registry alias;
3. exact display name plus at least one independent matching constraint.

Display name alone never resolves. An exact higher-rank match suppresses lower-rank
candidates. Equal-rank candidates remain a tie.

Area resolution is an independent constraint. An area name narrows candidates to
entities in that area. It cannot manufacture a candidate and cannot override an
explicit entity ID or contradictory area.

## Outcomes

- One admissible best candidate: `resolved` with stable ID, evidence kind, and spans.
- More than one admissible best candidate at the same rank: `ambiguous` with all
  candidate stable IDs in canonical order.
- No admissible candidate: `no_match`.
- Malformed request, invalid span, stale generation, contradictory constraint, or
  unsupported capability: `no_match` at the resolution boundary. A future protocol
  may distinguish malformed transport errors, but this preparation does not change
  protocol v1.

Canonical ordering is stable output formatting only. It is never semantic evidence.

## Negative rules

Reject or abstain on:

- fuzzy, edit-distance, phonetic, transliterated, or partial matching;
- case folding or accent folding beyond existing contract normalization;
- display-name-only resolution;
- conflicting domain or area constraints;
- disabled, unexposed, unknown, or stale targets;
- invalid, reversed, overlapping, or out-of-request spans;
- duplicate stable IDs or duplicate dotted IDs;
- generic Home Assistant service names.

## Acceptance criteria

Future implementation must demonstrate:

1. exact external ID precedence over alias and display name;
2. explicit alias precedence over display name;
3. area-constrained unique resolution;
4. entity and area ambiguity abstention;
5. no-match for unknown and contradictory requests;
6. stale-generation rejection;
7. catalog permutation determinism;
8. valid half-open span preservation;
9. zero false plans and zero unsafe partial publication;
10. no regression in MLP baselines A and B;
11. no protocol v1 or integration behavior change without a new ADR.

## Independent evaluation

The prepared corpus, oracle, generator, and freeze are under
`evaluation/ptbr-independent/entity-resolution/`. They are project-authored
synthetic conformance evidence, not linguistic accuracy data. Gold labels are
written before any product implementation and must not be changed from product
outputs.

The freeze must pass with `freeze.py --check`. A future implementation must register
its own pre-change and post-change results separately. Existing A/B artifacts remain
untouched.

## Rollback and activation

Until a future ADR changes this status, no runtime code is active. If acceptance
fails, retain the evidence and keep the MLP behavior unchanged. Do not activate
legacy `ha-catalog`, `plan-engine`, or `session-engine` crates automatically.
