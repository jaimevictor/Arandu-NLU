# P07 Morphology Validation Evidence

- Phase: `P07`
- Candidate: `37929728cc38761548d1693c6adb3a78bc518a2e`
- Candidate tree: `737a42e85e3b570f49c68f5234fe0f138098bc54`
- Convergence pass: 1 of 3
- Candidate round: 1 of 3
- Validation time: `2026-08-29T01:17:58Z`
- Result: `PASS`

## Scope

P07 wraps the exact P06 lexicon as lexical-evidence-only morphology. Production
returns all 33 source analyses over 32 surfaces, including four analyses with
empty feature sets and both analyses of the repeated surface. Unknown input
has no analysis payload. No inference, stemming, repair, ranking,
deduplication, case folding, or generated linguistic fact was added.

The isolated evaluator scores the frozen 29-analysis, 28-surface
feature-bearing P02 view as same-source internal conformance. It is not
independent accuracy, representativeness, unseen-form generalization, or
product-equivalence evidence.

## Executed Gates

The pre-freeze acceptance run executed:

- `tools/validate-p01`: workspace formatting, warnings-denied Clippy,
  all-feature tests, and all-target builds;
- `tools/test-validate-p01`: 9 dependency, schema, distribution, and source
  boundary mutations;
- `tools/validate-p02`, `tools/test-validate-p02`, and
  `tools/generate-p02-corpus --check`;
- `tools/validate-p04 --no-cargo` and `tools/test-validate-p04`;
- `tools/validate-p05 --no-cargo` and `tools/test-validate-p05`;
- `tools/validate-p06 --no-cargo` and `tools/test-validate-p06`;
- `tools/validate-p07` and `tools/test-validate-p07`;
- YAML and JSON parsing plus `git diff --check`.

Workspace execution passed 125 Rust tests: 39 `lang-ptbr`, 12
`morphology-eval`, 24 `nlu-core`, 29 `nlu-data`, and 21 `protocol` tests.
The P07 Ruby suite passed 7 mutation tests.

The P07 checks prove:

- all production morphology results borrow complete immutable P06 analyses;
- the exact repeated surface remains a two-analysis unranked ambiguity;
- the 32-analysis cap accepts 32 and rejects 33 without truncation;
- the manifest is hash-pinned before parsing and binds source, split, case,
  artifact, package, grouping, metric, confusion, error, and limitation
  identities;
- malformed UTF-8, duplicate keys and identities, trailing or oversized
  input, unsafe paths, and coordinated manifest substitutions fail closed;
- every metric carries domain, dataset ID/version, split, claim scope, and
  limitations with integer-only values;
- injected missing-analysis observations produce deterministic nonzero errors
  and confusion changes;
- production manifests and Rust sources contain no evaluator, oracle, case,
  report, or error-ledger dependency;
- evaluator output exactly equals the tracked canonical report.

The frozen baseline is:

- exact surface sets: `28/28`;
- analysis counts: `TP=29`, `FP=0`, `FN=0`;
- precision and recall: `29/29`;
- preserved ambiguity: `1/1`;
- confusion matrix: `[[0,0,0],[0,27,0],[0,0,1]]`;
- error analysis: the frozen taxonomy with zero baseline errors.

## Two-root Replay

The current evaluator ran against separate regular-file input roots
`/private/tmp/nlu-p07-root-a.LTEqUU` and
`/private/tmp/nlu-p07-root-b.SSBc2z`. Their manifest and oracle copies had
distinct inode identities. Both emitted bytes identical to each other and to
the tracked report, with SHA-256
`a383b8002b3125a048594f3c836835f3484e7b994da79bbf96756aa1340774d4`.

The frozen implementation identities are:

- runtime morphology source:
  `331d59ff38149a9d55e8d1cf4e14f679e1cfd8356c28df3ff60d2d66b8db0b89`;
- evaluator library:
  `3de9caefecf4d1b48ce9d781021816d56fe51433fb623115f4a83af3c3e7035e`;
- evaluation manifest:
  `2a3ff2ffa947749010c735b1f45af31a9d2a477cdfefa7ed8f7cafabb288a0b7`;
- canonical report:
  `a383b8002b3125a048594f3c836835f3484e7b994da79bbf96756aa1340774d4`.

Candidate round 1 is the first minimally acceptable baseline. It is frozen
without optional refinement. The user directed the executor to skip the final
phase review after successful mandatory gates; no separate phase-review report
is claimed.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks --no-local` created
`/private/tmp/nlu-p07-3792972.FEZfmn/repo` and checked out candidate
`37929728cc38761548d1693c6adb3a78bc518a2e` with tree
`737a42e85e3b570f49c68f5234fe0f138098bc54`. The clone had no object-store
alternate and an empty worktree status. Its evaluator source and copied
admitted Cargo executable had different inode identities from the candidate
worktree.

At `2026-08-29T01:21:09Z`, the clean clone reproduced:

- `tools/validate-p01`: `P01_GATE_PASS`;
- `tools/test-validate-p01`: 9 tests and `P01_GATE_TESTS_PASS`;
- `tools/validate-p02`: `P02_VALIDATION_PASS`;
- `tools/test-validate-p02`: 12 tests and `P02_VALIDATION_TESTS_PASS`;
- `tools/generate-p02-corpus --check`:
  `P02_CORPUS_GENERATION_CHECK_PASS`;
- `tools/validate-p04 --no-cargo`: `P04_GATE_PASS`;
- `tools/test-validate-p04`: 4 tests and `P04_GATE_TESTS_PASS`;
- `tools/validate-p05 --no-cargo`: `P05_GATE_PASS`;
- `tools/test-validate-p05`: 8 tests and `P05_GATE_TESTS_PASS`;
- `tools/validate-p06 --no-cargo`: `P06_GATE_PASS`;
- `tools/test-validate-p06`: 5 tests and `P06_GATE_TESTS_PASS`;
- `tools/validate-p07`: `P07_GATE_PASS`;
- `tools/test-validate-p07`: 7 tests and `P07_GATE_TESTS_PASS`;
- YAML parsing and `git diff-tree --check HEAD^ HEAD`.

The manifest, report, validator, validator-test, commit, and tree identities
matched the frozen candidate. The clone remained clean. This is deterministic
candidate reproduction, not a separate final phase review.
