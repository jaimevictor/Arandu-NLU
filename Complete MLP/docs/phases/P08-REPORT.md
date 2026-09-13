# P08 Conservative Contextual POS Report

- Phase: `P08`
- State: `COMPLETE`
- Subject: `ac13303ac9c9751aece275563070a72c574f24ca`
- Subject tree: `4938fa60ca0d683a3656138e5c7a63d6a1be2b1d`
- Convergence passes consumed: 2 of 3
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P08 adds a deterministic baseline, a train-only adjacent-transition model, a
47-byte embedded package, and an isolated evaluator. Context may remove one
unsupported candidate only when one non-cascading adjacent singleton uniquely
supports the alternative. It cannot tag unknown input or manufacture
linguistic evidence.

Train, development, and heldout records preserve the frozen source bytes and
are sentence-, document-, and family-disjoint. Model and report generation are
canonical, integer-only, offline, seed-fixed, and byte-reproducible.

## Validation

The frozen heldout result is 561/643 exact token sets for the baseline and
562/643 for the selected method. Both methods recognize all four expected
unknowns and leave 80 unsupported known tokens unknown. The selected method
resolves one of two ambiguity cases and preserves the other.

All results are same-source internal conformance. They do not establish
independent PT-BR accuracy, representativeness, unseen-language performance,
cross-origin generalization, or equivalence to another product.

One user-directed public-source check rejected GSD, PetroGold, and Porttinari
because rights over their underlying text were absent, disclaimed, or
unproven. No rejected byte influenced the project.

A no-hardlink, no-local clone reproduced the exact candidate, all inherited
gates, split generation, training, two-root evaluation, schemas, and mutation
suites offline with a copied admitted toolchain. The clone had no object
alternate and remained clean.

## Convergence

The selected implementation met minimum acceptance in convergence pass 1.
The bounded external-source check consumed pass 2 without replacing it.
Candidate round 1 is frozen immediately. No optional refinement follows, one
convergence pass remains unused, and two candidate rounds remain available
only for reproduced blockers.

## Review State

The user directed the executor to skip the final phase review after successful
mandatory gates. No separate post-candidate phase review is claimed.

## Next State

After exact-commit reproduction, the evidence-only closeout advances the queue
to P09 intent recognition without changing the P08 subject.
