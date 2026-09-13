# P05 Tokenization Validation Evidence

- Phase: `P05`
- Candidate: `f5104beb6f63a23ed38e2d04fbf4cbe35ccb2f96`
- Candidate tree: `cc8d4c35a214430dabd6ea77816f8510f40f6e90`
- Convergence pass: 2 of 3
- Candidate round: 1 of 3
- Validation time: `2026-08-29T00:08:58Z`
- Full gate time: `2026-08-29T00:10:57Z`
- Reproduction time: `2026-08-29T00:17:43Z`
- Result: `PASS`

## Scope

P05 adds deterministic, source-bounded tokenization over P04
`NormalizedText`. Every token has normalized and original UTF-8 byte spans,
a closed class, a closed boundary operation, and a stable rule ID. Logical
parts project to the complete source surface and never invent byte evidence.

The admitted behavior is intentionally narrow: exact Unicode ASCII
punctuation, CLDR decimal-comma and `HH:mm` shapes, two CLDR unit literals,
four UD contractions, two UD clitic forms, and one UD abbreviation. Every
other linguistic fact remains unknown.

## Source Admission

Convergence pass 1 was rejected and contributes no runtime rule. Pass 2 uses
Unicode 17, UD Portuguese documentation, and CLDR 48. Five distinct read-only
reviewers passed the same source candidate, material projection, distribution
projection, tokenizer, and validator hashes with no P0-P3 findings.

The admission gate reconstructs the exact pre-promotion source ledger bytes
and validates complete canonical projections of the P05 material and
distribution records. Retained files, licenses, rule tables, and path-bound
metadata remain independently removable by source ID.

## Executed Gates

The complete pre-freeze acceptance run executed:

- `tools/validate-p01`: `P01_GATE_PASS`;
- `tools/test-validate-p01`: 8 tests and `P01_GATE_TESTS_PASS`;
- `tools/validate-p05`: `P05_GATE_PASS`;
- `tools/test-validate-p05`: 8 tests and `P05_GATE_TESTS_PASS`;
- `tools/validate-p04`: `P04_GATE_PASS`;
- `tools/test-validate-p04`: 4 tests and `P04_GATE_TESTS_PASS`;
- `tools/validate-p02`: `P02_VALIDATION_PASS`;
- `tools/test-validate-p02`: 12 tests and `P02_VALIDATION_TESTS_PASS`;
- `tools/generate-p02-corpus --check`:
  `P02_CORPUS_GENERATION_CHECK_PASS`.

The P01 gate ran workspace formatting, warnings-denied Clippy, all-feature
workspace tests, and all-target builds with the admitted offline toolchain and
vendored dependency closure. Focused `lang-ptbr` execution passed 28 tests.
YAML parsing and `git diff --check` also passed.

Candidate round 1 is the first baseline to satisfy minimum acceptance. It was
frozen immediately. Convergence stopped at pass 2 of 3 and candidate review
stopped at round 1 of 3; no optional refinement followed.

The user directed the executor to skip the final phase review after successful
mandatory gates. The five source-admission reviews remain independently
recorded; no separate post-candidate phase review is claimed.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks` created the clean source root
`/private/tmp/nlu-p05-f5104be.9o77wl/repo`. It checked out candidate
`f5104beb6f63a23ed38e2d04fbf4cbe35ccb2f96` with tree
`cc8d4c35a214430dabd6ea77816f8510f40f6e90`, an empty worktree status, and no
object-store alternate. The tokenizer and copied toolchain executable had
different inode identities from the candidate worktree.

The admitted `.tools` directory is an ignored ambient build input and was
copied into the clone. No dependency or source fetch occurred. Cargo used only
the committed vendor directory with offline mode.

Inside that clone:

- `tools/validate-p01` returned `P01_GATE_PASS`;
- `tools/test-validate-p01` passed 8 tests;
- `tools/validate-p05` returned `P05_GATE_PASS`;
- `tools/test-validate-p05` passed 8 tests;
- `tools/validate-p04` returned `P04_GATE_PASS`;
- `tools/test-validate-p04` passed 4 tests;
- `tools/validate-p02` returned `P02_VALIDATION_PASS`;
- `tools/test-validate-p02` passed 12 tests;
- `tools/generate-p02-corpus --check` returned
  `P02_CORPUS_GENERATION_CHECK_PASS`;
- focused `cargo test -p lang-ptbr --all-features` passed 28 tests;
- all 10 YAML files parsed, and `git diff-tree --check HEAD^ HEAD` passed.

The reproduced tokenizer, validator, validator-test, source-ledger, material,
and distribution hashes matched the candidate values exactly. This is
candidate-controlled deterministic reproduction, not an independent final
phase review.
