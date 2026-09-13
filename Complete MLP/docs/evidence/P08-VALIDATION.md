# P08 Contextual POS Validation Evidence

- Phase: `P08`
- Candidate: `ac13303ac9c9751aece275563070a72c574f24ca`
- Candidate tree: `4938fa60ca0d683a3656138e5c7a63d6a1be2b1d`
- Convergence passes consumed: 2 of 3
- Candidate round: 1 of 3
- Validation date: `2026-08-28`
- Result: `PASS`

## Scope

P08 adds a documented independent-evidence baseline and one conservative
contextual POS method. The baseline returns every P07 lexical POS candidate,
maps the P05 numeric class to source-backed `NUM`, and leaves unsupported
input payload-free. The selected method narrows an existing ambiguity only
when a train-observed adjacent singleton transition uniquely supports one
candidate.

Selection is non-cascading. Missing, tied, contradictory, unknown, or
ambiguous context preserves the complete baseline candidate set. The method
never adds a candidate, tags an unknown, ranks package order, reads a runtime
file, or uses heldout observations.

The 241 project-authored sentences are split byte-for-byte into 80 train, 80
development, and 81 heldout records. Sentence bytes, sentence hashes,
documents, and generator families are disjoint across splits. All rows share
one origin, so the result is same-source internal conformance rather than
independent Portuguese accuracy or cross-origin generalization.

## Source Check

At the user's direction, one bounded external POS source check inspected
current exact revisions of UD Portuguese GSD, PetroGold, and Porttinari in
temporary quarantine. GSD disclaims rights over potentially copyrighted
underlying text. Porttinari uses Folha de S.Paulo articles without an
underlying rightsholder grant. PetroGold does not identify a source license or
commercial redistribution grant for each of its 19 complete academic
documents.

All three candidates were rejected before admission. No candidate byte entered
the repository or influenced implementation or evaluation. The exact
disposition is recorded in
`docs/evidence/sources/p08-ptbr-pos-candidates-rejection.md`.

## Frozen Artifacts

- split manifest SHA-256:
  `bd6ef5cf79e188d43eb6b6ecddd4de7e5f767aab14316a3a4b677a04d9c2fb5c`;
- model package: 47 bytes, SHA-256
  `23beb6dd464c4bd03d69bb374be210fd3a187661c37673194f466b4270b8020c`;
- model manifest SHA-256:
  `f89eaa786f37456d5e1d47e522ceea7bd96f41b272bdc9a6ca99407d7cc2b0bc`;
- evaluation manifest SHA-256:
  `c4ca9531c45eaff9df8a79f48a060f7a1716c3102b37b4caa24a5cba708ff048`;
- canonical report SHA-256:
  `ffc8ea80508d1bd7505e73eefb26969babac9d4de9ba7b4014cc52a78c913982`.

The model format is strict `NLUPOS\0` version 1 with five labels and seven
sorted unique transitions. The manifest fixes seed `0`, records that no
randomness is used, and binds the source, generator, specification, physical
train slice, training inventories, compiler, configuration, and package.

## Results

The frozen heldout comparison contains 643 tokens in 81 sentences and 9
documents:

| Metric | Baseline | Selected |
| --- | ---: | ---: |
| exact token candidate sets | 561/643 | 562/643 |
| exact sentences | 0/81 | 0/81 |
| exact documents | 0/9 | 0/9 |
| exact origins | 0/1 | 0/1 |
| expected unknowns correct | 4/4 | 4/4 |
| unsupported known tokens left unknown | 80 | 80 |
| exact ambiguity cases | 0/2 | 1/2 |
| unresolved ambiguity cases | 2/2 | 1/2 |
| candidate TP / FP / FN | 559 / 2 / 80 | 559 / 1 / 80 |

The selected method improves one exact token set and removes one false
positive without changing false negatives or unknown behavior. One ambiguity
remains unresolved as required by the fail-closed context rule. Heldout
improvement is reported but was not an acceptance threshold and did not
trigger tuning.

## Verification

The candidate validation portfolio executes:

- `tools/validate-p01` and `tools/test-validate-p01`;
- `tools/validate-p02`, `tools/test-validate-p02`, and
  `tools/generate-p02-corpus --check`;
- `tools/validate-p04 --no-cargo` through
  `tools/validate-p07 --no-cargo` and each corresponding mutation suite;
- `tools/test-compile-p08-pos-splits`;
- `tools/validate-p08` and `tools/test-validate-p08`;
- YAML and JSON parsing plus `git diff --check`.

The P08 gate hash-pins every source, split, package, manifest, report, and
schema artifact. It rebuilds the split, trains twice in separate input roots,
reproduces byte-identical model artifacts, and evaluates twice from separate
heldout-only roots. Both evaluator outputs equal the tracked report. Train and
development slices are absent from evaluator roots.

Production dependency and source scans prove that no production crate depends
on `pos-eval` or contains heldout paths, expected labels, metric taxonomy,
filesystem, network, locale, time, entropy, or mutable evaluator state. The
runtime package is embedded and strictly decoded under count and byte limits.

The P08 Ruby suite rejects coordinated source, configuration, seed, package,
split, metric, report, requirement, duplicate-key, and production-oracle
mutations. Rust tests cover malformed UTF-8 and JSON, bad spans, duplicate
identities, one-over limits, noncanonical packages, traversal, symlinks,
unknown barriers, contradictory context, ambiguity retention, non-cascading
selection, dependency isolation, and CLI failures with no partial output.

The implementation tuple met minimum acceptance in convergence pass 1. The
user-directed source portfolio check consumed pass 2 and rejected all
replacements without changing the tuple. Candidate round 1 is therefore
frozen immediately, with no optional refinement or post-candidate final
review.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks --no-local` created
`/private/tmp/nlu-p08-ac13303.55vnEL/repo` at candidate
`ac13303ac9c9751aece275563070a72c574f24ca` and tree
`4938fa60ca0d683a3656138e5c7a63d6a1be2b1d`. The clone had no object-store
alternate, no loose borrowed objects, and an empty worktree status. Its
validator and copied admitted Cargo executable had inode identities distinct
from the candidate worktree.

At `2026-08-29T02:05:32Z`, the clean clone reproduced:

- `tools/validate-p01`: `P01_GATE_PASS`;
- `tools/test-validate-p01`: 9 tests and `P01_GATE_TESTS_PASS`;
- `tools/validate-p02`: `P02_VALIDATION_PASS`;
- `tools/test-validate-p02`: 12 tests and
  `P02_VALIDATION_TESTS_PASS`;
- `tools/generate-p02-corpus --check`:
  `P02_CORPUS_GENERATION_CHECK_PASS`;
- `tools/validate-p04 --no-cargo`: `P04_GATE_PASS`;
- `tools/test-validate-p04`: 4 tests and `P04_GATE_TESTS_PASS`;
- `tools/validate-p05 --no-cargo`: `P05_GATE_PASS`;
- `tools/test-validate-p05`: 8 tests and `P05_GATE_TESTS_PASS`;
- `tools/validate-p06 --no-cargo`: `P06_GATE_PASS`;
- `tools/test-validate-p06`: 5 tests and `P06_GATE_TESTS_PASS`;
- `tools/validate-p07 --no-cargo`: `P07_GATE_PASS`;
- `tools/test-validate-p07`: 7 tests and `P07_GATE_TESTS_PASS`;
- `tools/test-compile-p08-pos-splits`: 9 tests and
  `P08_POS_SPLIT_COMPILER_TESTS_PASS`;
- `tools/validate-p08`: `P08_GATE_PASS`;
- `tools/test-validate-p08`: 11 tests and `P08_GATE_TESTS_PASS`;
- YAML and JSON parsing plus `git diff-tree --check HEAD^ HEAD`.

The clean clone reproduced the exact split, model, manifest, report, runtime,
trainer, evaluator, validator, commit, and tree identities. Both fresh-target
Cargo gates passed, and the clone remained clean. This is deterministic
candidate reproduction, not a separate final phase review.
