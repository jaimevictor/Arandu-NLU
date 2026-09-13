# P11 Evidence-Bound Plan Composition Validation

- Phase: `P11`
- Candidate: `2784120d9bd5ea106e7535406135ebb76b7939b4`
- Candidate tree: `f35629712d4d2d00da8dc4705a0a3c54560730be`
- Convergence passes consumed: 1 of 3
- Candidate round: 1 of 3
- Validation date: `2026-08-29`
- Result: `PASS`

## Scope

P11 adds dependency-free `nlu-core::ComposedPlan`, the authority-free
`plan-engine` composer, and production-isolated `plan-eval`. A composed plan
contains typed clause evidence, explicit polarity, evidence-bearing
relations, independent node pairs, argument shares, and a derived graph
execution class.

Every node requires predicate evidence. Every slot requires one direct
argument or one validated inbound share. Negation, relation, independence,
sharing, endpoint, generation, acyclicity, conflict, canonical ordering,
aggregate, template, and encoded-byte invariants fail closed. The composer
uses 20 closed templates under a hard limit of 32 and never creates a node
from a connective alone or returns a successful subset after another clause
fails.

Protocol v1 remains unchanged. P11 graph classes are descriptive and grant no
policy, authorization, adapter, or execution authority.

## Frozen Artifacts

- semantic-plan schema SHA-256:
  `612c12f58afbadf7bff54dcda31e1fd5278edad40506b5683e5fd2cb453351c7`;
- evaluation-report schema SHA-256:
  `018499a30b06233956d366f6b3eb72096047dc1d842f3909753bb99c4afbdd0c`;
- train report SHA-256:
  `ef3ac647975a89285e3478a18967c9404997763258245511ce804daaf331ddba`;
- development report SHA-256:
  `ae2d822c1bf8d68ed210cdaa22420f5ca6c539a1fb29e77eda60481e3c28900e`;
- validator SHA-256:
  `dbd5fddd40509975f91766b5de947ea61f7135d66a01fd760c77b37353910428`;
- validator mutation suite SHA-256:
  `62f8f65465926817fb2b452dc0ccbfd303ffd327670b78b17c0ed017a8bf0fb1`.

The gate also pins the P09 projection, P02 train and development records, the
admitted P02 ambiguity and contradiction suites, and the pre-composer P11
negation supplement. It admits no held-out path.

## Results

| Metric | Train | Development |
| --- | ---: | ---: |
| intent exact | 963/963 | 387/963 |
| outcome exact | 963/963 | 1/963 |
| full graph exact | 962/962 | 0/962 |
| canonical bytes exact | 962/962 | 0/962 |
| exact semantics | 963/963 | 1/963 |

Train produced 963 recognizer matches, 962 plans, and one fail-closed
negation-scope abstention. Development produced 387 recognizer matches and 576
recognizer abstentions; composition produced 387 abstentions and did not run
for the other 576 records.

These results are project-authored internal conformance only. No P11
acceptance threshold exists, development output cannot authorize runtime
rules or refinement, and neither split establishes independent PT-BR
accuracy.

## Coverage

The evaluation reconciles all 963 records into single, parallel-pair,
ordered-pair, clear first-node negation, clear second-node negation, and
ambiguous shared-negation strata. The admitted P02 suites additionally bind
`coordination_scope` and all five contradiction classes:
`opposite_actions_same_target`, `incompatible_positions`,
`start_and_cancel_timer`, `cyclic_order`, and `state_action_conflict`.

The admitted counterexample `ligue a luz e o ventilador da sala` is exercised
exactly. P09 abstains, so P11 returns no plan and never treats the connective
as sufficient clause evidence.

## Verification

The candidate and closeout validation executed:

- `tools/validate-p11 --review-candidate`;
- `tools/test-validate-p11`, with 16 passing mutation tests;
- the full pending-requirement candidate gate and clean exact-commit replay;
- `tools/validate-p11` after requirement closeout;
- deterministic supplement regeneration and two identical evaluator replays
  for each admitted split;
- forbidden held-out, test, validation, and holdout split attempts;
- strict clippy with warnings denied, locked tests, format, and all-target
  builds;
- full workspace tests, clippy, format, and build;
- `tools/validate-p01`, `tools/test-validate-p01`, inherited phase gates and
  mutation suites; and
- `git diff --check`.

Tests cover missing and duplicate evidence, dangling endpoints, relation and
share cycles, mixed or stale generations, semantic conflicts, ambiguity,
unsupported propagation, canonical permutations, protocol-v1 compatibility,
privacy canaries, exact and one-over limits, and the 32/33 template boundary.

## Exact-Commit Reproduction

The clean working tree at candidate
`2784120d9bd5ea106e7535406135ebb76b7939b4` and tree
`f35629712d4d2d00da8dc4705a0a3c54560730be` reproduced the frozen source,
schemas, focused Cargo checks, both reports, deterministic replays, forbidden
split denials, and candidate gate. The worktree was clean before evidence
closeout began. This was deterministic candidate reproduction, not a separate
final phase review.

## Completion

The first complete implementation met the written minimum in convergence pass
1 and was frozen immediately as candidate round 1. The user directed the
executor to skip the post-candidate final review after successful mandatory
validation. No optional refinement or separate final phase review is claimed.
