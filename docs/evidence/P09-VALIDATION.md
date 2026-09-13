# P09 Intent Recognition Validation Evidence

- Phase: `P09`
- Candidate: `6c6d4804a1b4b94867578ad5febb83243e0b31f4`
- Candidate tree: `e51f10ba4a4ebe621a819de1ce08f67800d36216`
- Convergence passes consumed: 1 of 3
- Candidate round: 1 of 3
- Validation date: `2026-08-28`
- Result: `PASS`

## Scope

P09 adds a strict versioned intent schema, a canonical embedded package, a
production intent recognizer, and an isolated evaluator. The recognizer emits
exactly one match, a canonical clarification, or an abstention. It has no
entity-resolution, graph, policy, execution, response-rendering, filesystem,
network, time, entropy, or Home Assistant authority.

Every accepted slot has a stable identifier, role and occurrence, a closed
typed value, and a nonempty checked half-open span into the original UTF-8
request. Candidate generation is package-backed, scoring is bounded integer
arithmetic, and neither schema order nor candidate insertion order may select
an ambiguity winner.

Only the P02 train split contributes linguistic markers to the runtime
package. The evaluator uses the independently frozen pre-engine projection
and development split. The P02 heldout split remained sealed, and recognizer
output was never used as evaluation gold.

## Frozen Artifacts

- intent schema source: 15,298 bytes, SHA-256
  `be9fc531981b5581cbbe4577cd5b1e6194bd98470f84c13781b221472dfd54f9`;
- intent package: 9,621 bytes, SHA-256
  `56140cfa9d93377145aac132a174ed79262e9f454b6e991118477e3ad54bddda`;
- package manifest SHA-256:
  `cdef4653c0edc5d819fc52ec0c03976f6df66d0036dff9828b410f699f44ffc3`;
- pre-resolution projection SHA-256:
  `5f661bb96b85667a1d0c9ec4d85cb61c443e1b24ab4dfc6c1ab849c6df936ee4`;
- canonical development report SHA-256:
  `cf3b150f9f415a111cda5e874b57254f0637dee938150ceca8d88c1ea0988ad0`.

The package manifest binds the source, corpus version, generator,
specification, physical train input, schema, compiler, algorithm,
configuration, package bytes, and `randomness_used: false`. The package
decoder rejects unknown versions, malformed framing, noncanonical order,
duplicates, invalid identifiers or constraints, truncation, trailing bytes,
substitution, and exact one-over resource limits before interpretation.

## Results

The train replay produced 960/960 exact pre-resolution semantics and
1,248/1,248 exact slot values and spans.

The frozen development result is:

| Metric | Result |
| --- | ---: |
| exact pre-resolution semantics | 384/960 |
| matches | 384 |
| clarifications | 0 |
| abstentions | 576 |
| errors | 0 |
| exact slot values | 528/1,248 |
| exact slot spans | 528/1,248 |
| missing slots | 720 |
| incorrect or unexpected slots | 0 |

All 20 intent strata and all 26 slot strata reconcile exactly. Eight intent
families match all 48 development records; twelve abstain on all 48. The
result establishes same-source internal conformance only. It does not
establish independent PT-BR accuracy, natural-language representativeness,
cross-origin generalization, entity resolution, or complete plan accuracy.
Development results did not authorize a refinement pass.

## Verification

The candidate validation portfolio executed:

- `tools/validate-p09 --review-candidate` before candidate freeze for the
  artifact, source, schema, package, projection, report, isolation, and
  pending-requirement contract;
- `tools/validate-p09` during closeout for the satisfied-requirement gate,
  package and report reproduction, and focused Cargo checks;
- `tools/test-validate-p09`, covering coordinated artifact, package version,
  trailing-byte, schema identity, output-oracle, metric, denominator,
  production-isolation, requirement-state, and duplicate-key mutations;
- `tools/validate-p01` and `tools/test-validate-p01`;
- `tools/validate-p02`, `tools/test-validate-p02`, and
  `tools/generate-p02-corpus --check`;
- inherited P04-P08 validators and mutation suites;
- JSON and YAML parsing plus `git diff --check`.

The Rust tests exercise malformed schema and packages, strict construction,
canonical compilation, package and input permutations, checked multibyte
spans, value bounds, ambiguity margins, threshold abstention, unknown and
contradictory evidence, integer and candidate limits, complete metric
reconciliation, and CLI failure without partial output.

The production source and dependency scans exclude the evaluator, expected
labels, development and heldout paths, filesystem and network access, time,
entropy, policy, execution, and resolved entity values. The P05 fail-closed
tokenizer behavior for unsupported `alto-falante` remains one preserved
unknown token and is covered by regression tests.

The first complete implementation met every mandatory check in convergence
pass 1 and was frozen as candidate round 1. The user directed the executor to
skip the post-candidate final review after a successful run. No optional
refinement or additional review is claimed.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks --no-local` created
`/private/tmp/nlu-p09-6c6d480.FRPnJ0/repo` at candidate
`6c6d4804a1b4b94867578ad5febb83243e0b31f4` and tree
`e51f10ba4a4ebe621a819de1ce08f67800d36216`. The clone had no object-store
alternate and an empty worktree status.

The clean clone reproduced the P09 schema, package, manifest, projection,
train and development reports, focused Cargo tests, P09 gate, P09 mutation
suite, P01 full gate, and P01 mutation suite using the copied admitted
toolchain offline. It remained clean after execution. This is deterministic
candidate reproduction, not a separate final phase review.
