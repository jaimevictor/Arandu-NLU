# P02 Corpus And Source Report

- Phase: `P02`
- State: `COMPLETE`
- Subject: `24af7cef7d949ae8b796e91f6c3910805c28ac1e`
- Subject tree: `0a0dfcbe867ed2f5efb9f7b158164f5d2ff3717f`
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P02 records a bounded external-source search and rejection history, a measured
corpus-free fallback, and the user-authorized replacement corpus. The
replacement is a deterministic Apache-2.0
`PROJECT_AUTHORED_SYNTHETIC` PT-BR package whose labels are fixed by a
versioned generator specification before NLU implementation.

The package provides strict schemas, a deterministic generator, a fail-closed
validator, mutation tests, train and development sets, a 4,800-case held-out
set, a separate 4,800-case performance set, contextual POS cases, lexicon and
morphology cases, and five fail-closed suites. It adds no runtime dependency,
crate, network access, or execution authority.

## Coverage

The held-out and performance sets cover all 20 built-in intent families in the
pinned Home Assistant public intent contract. Each family has 240 cases in
each set. The manifest freezes source, family, intent, domain, slot-kind,
graph-shape, outcome, ambiguity, noise, and target-cardinality counts.

The held-out total exceeds the retained 3,715-case floor. Every declared
mandatory held-out and performance stratum exceeds the retained 237-case
floor. Case, generator, semantic, text, and family-disjointness controls
prevent duplicate or cross-split credit.

The five non-plan suites contain 27 unique classes covering sensitive
operations, contradictions, ambiguity, stale state, unsupported behavior, and
explicit negatives.

## Validation

Syntax checks passed for all six entry points. The 12-test validator suite,
two-root generation comparison, byte reproduction check, and complete corpus
validation passed. The inherited P01 build/license gate and its four mutation
tests also passed. Exact command results, artifact counts, and the
non-applicable P00-only launcher result are recorded in
`docs/evidence/P02-VALIDATION.md`.

All new paths are project-authored Apache-2.0 paths in the distribution
license manifest. No rejected external data remains in the repository and no
new software dependency was added.

## Boundaries

This corpus supports internal conformance only. It does not establish
independent PT-BR accuracy, population representativeness, comparative product
quality, or Sophia equivalence. P15 must preserve that claim boundary.

The corpus freezes the P02 data contract; it does not implement tokenization,
morphology, parsing, intent recognition, policy, Home Assistant execution,
transport, response rendering, packaging, or the P03 data pipeline.

## Convergence

Three pre-candidate source passes and the single user-authorized recovery pass
were consumed before `USR-016` changed the allowable corpus origin. This is
the first substantive frozen P02 candidate. It passed without a remediation
round, and no optional refinement pass follows.

The user directed the executor to skip the final review after the successful
run and move on. No independent review result is claimed. The unavailable
independent pre-phase analyses and final P02 review roles are explicitly
waived for this closeout only.

## Next State

The evidence-only closeout checkpoint records the candidate commit and tree,
closes P02, advances the queue to P03, and starts the deterministic
data-pipeline phase. No optional P02 refinement or additional review pass
follows.
