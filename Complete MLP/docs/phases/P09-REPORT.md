# P09 Evidence-Bearing Intent Recognition Report

- Phase: `P09`
- State: `COMPLETE`
- Subject: `6c6d4804a1b4b94867578ad5febb83243e0b31f4`
- Subject tree: `e51f10ba4a4ebe621a819de1ce08f67800d36216`
- Convergence passes consumed: 1 of 3
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P09 adds a strict intent-schema compiler, canonical embedded package,
production intent engine, and production-isolated evaluator. Recognition
returns one typed match, all hypotheses inside the ambiguity margin, or an
abstention. Stable intent and slot identifiers, bounded integer ranking,
closed typed values, and checked original UTF-8 spans make every result
auditable.

The engine cannot resolve Home Assistant entities, construct plan graphs,
apply policy, execute operations, render responses, read runtime files, or
access a network. Those boundaries remain assigned to later phases.

## Validation

Train replay is 960/960 exact pre-resolution semantics with 1,248/1,248 exact
slot values and spans. Development is 384/960 exact semantics: 384 matches,
576 abstentions, no clarifications, and no errors. Of 1,248 expected
development slots, 528 have exact values and spans and 720 are missing because
their complete hypotheses abstain; none is incorrect or unexpected.

These are same-source internal-conformance results from project-authored
templatic data. They are not claims of independent PT-BR accuracy,
generalization, entity resolution, or complete plan accuracy.

The frozen artifact hashes, all 20 intent strata, all 26 slot strata, package
reproduction, two-split evaluation, inherited gates, mutation suites, and
production isolation checks passed. A no-hardlink, no-local clone reproduced
the exact candidate and remained clean.

## Convergence

The first complete implementation met the written minimum acceptance in
convergence pass 1 and was frozen as candidate round 1. Two convergence passes
and two candidate rounds remain unused and are not refinement entitlement.

## Review State

The user directed the executor to skip the final phase review after successful
mandatory validation. No separate post-candidate phase review is claimed.

## Next State

The evidence-only closeout advances the queue to P10 Home Assistant catalog
contracts without changing the P09 subject.
