# P06 Lexicon Validation Evidence

- Phase: `P06`
- Candidate: `66f1d6aea06d314e873d29ee40fcd447fa9fe7b0`
- Candidate tree: `e5d041a21b6453ae043247b4c142313f2704f520`
- Convergence pass: 1 of 3
- Candidate round: 1 of 3
- Validation time: `2026-08-29T00:45:44Z`
- Result: `PASS`

## Scope

P06 compiles the exact 33-entry P02 project-authored lexical source into a
deterministic provenance-bearing package and embeds it in a private read-only
runtime index. It adds no lexical fact. Both source analyses of the repeated
surface remain observable in canonical order.

Every entry retains its source, artifact, record, generator, specification,
generation parameters, semantic identity, ordered transformation hashes,
partition, and derivative license. Compilation checks the independently pinned
source-manifest hash before opening any manifest-selected path.

## Executed Gates

The pre-freeze acceptance run executed:

- `tools/validate-p01`: workspace formatting, warnings-denied Clippy,
  all-feature workspace tests, and all-target builds;
- `tools/test-validate-p01`: inherited validator mutations;
- `tools/validate-p02` and `tools/test-validate-p02`;
- `tools/generate-p02-corpus --check`;
- `tools/validate-p04 --no-cargo` and `tools/test-validate-p04`;
- `tools/validate-p05 --no-cargo` and `tools/test-validate-p05`;
- `tools/validate-p06` and `tools/test-validate-p06`;
- YAML parsing and `git diff --check`.

Focused Rust execution passed 33 `lang-ptbr` tests, 18 `nlu-data` unit tests,
5 P06 cross-package contract tests, and 6 inherited pipeline contract tests.

The P06 tests independently prove:

- API, copied-clean-root, and CLI compilation reproduce the tracked bytes;
- all 33 entries preserve exact source fields and complete lineage;
- a coordinated manifest rewrite is rejected before its forged path is read;
- reversed source rows compile identically and preserve the source conflict;
- malformed framing, limits, ordering, inventory, licenses, locators, and
  lineage fail closed even when outer hashes are recomputed;
- source removal yields a valid empty package, empty inventories, and no
  source-ID bytes, while opaque technical structures prove selective removal;
- public schemas are closed and match every emitted top-level field.

Candidate round 1 is the first minimally acceptable baseline. It was frozen
without optional refinement. The user directed the executor to skip the final
phase review after successful mandatory gates; no separate phase-review report
is claimed.

The frozen generated identities are:

- compiler source:
  `3ffac0fe39c43ad5bb5abe849bdf2053ade4eaa60127af735bbd70a769a99605`;
- package:
  `ec24f2335f64d694931450fb5ad6aefe3e924d1e29b23e046f128491dfe79e27`;
- canonical sidecar:
  `f8f69336c9c682c225f7b972d56a66d1818e0f9c5fcf39455d38a636b38bb68b`.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks --no-local` created
`/private/tmp/nlu-p06-66f1d6a.vxzOQX/repo` and checked out candidate
`66f1d6aea06d314e873d29ee40fcd447fa9fe7b0` with tree
`e5d041a21b6453ae043247b4c142313f2704f520`. The clone had no object-store
alternate and an empty worktree status. Its lexical compiler and copied
admitted toolchain executable had different inode identities from the
candidate worktree.

At `2026-08-29T00:47:58Z`, the clean clone reproduced:

- `tools/validate-p01`: `P01_GATE_PASS`;
- `tools/test-validate-p01`: 8 tests and `P01_GATE_TESTS_PASS`;
- `tools/validate-p02`: `P02_VALIDATION_PASS`;
- `tools/test-validate-p02`: 12 tests and `P02_VALIDATION_TESTS_PASS`;
- `tools/generate-p02-corpus --check`:
  `P02_CORPUS_GENERATION_CHECK_PASS`;
- `tools/validate-p04 --no-cargo`: `P04_GATE_PASS`;
- `tools/test-validate-p04`: 4 tests and `P04_GATE_TESTS_PASS`;
- `tools/validate-p05 --no-cargo`: `P05_GATE_PASS`;
- `tools/test-validate-p05`: 8 tests and `P05_GATE_TESTS_PASS`;
- `tools/validate-p06`: `P06_GATE_PASS`;
- `tools/test-validate-p06`: 5 tests and `P06_GATE_TESTS_PASS`;
- YAML parsing and `git diff-tree --check HEAD^ HEAD`.

The package, sidecar, validator, validator-test, commit, and tree identities
matched the frozen candidate. The clone remained clean. This is deterministic
candidate reproduction, not a separate final phase review.
