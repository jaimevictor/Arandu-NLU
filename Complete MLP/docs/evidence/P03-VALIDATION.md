# P03 Data Pipeline Validation Evidence

- Phase: `P03`
- Candidate: `80672238116c125a4174329ce03e67ac88f42d5f`
- Candidate tree: `a5296aa0e7d2f4013974a8b9fbce2bd5650802d8`
- Candidate round: 1 of 3
- Validation time: `2026-08-28T22:19:59Z`
- Reproduction time: `2026-08-28T22:24:19Z`
- Source: `project-authored-synthetic-ptbr-v1` version `1.0.0`
- Authorization: `USR-016`
- Result: `PASS`

## Scope

This evidence covers the deterministic local `nlu-data` pipeline. The only
linguistic input is the Apache-2.0 project-authored P02 conformance corpus.
That corpus remains limited to internal conformance and does not establish
independent PT-BR accuracy, representativeness, or Sophia equivalence.

The pipeline has no network client. `fetch` is an explicitly authorized local
manifest copy, and normal build, validation, import, normalization, splitting,
compilation, and removal stay offline.

## Executed Gates

The final complete runs returned their exact pass sentinels:

```text
tools/validate-p01
tools/test-validate-p01
tools/validate-p02
tools/test-validate-p02
tools/generate-p02-corpus --check
```

Results:

- `tools/validate-p01`: `P01_GATE_PASS`
- `tools/test-validate-p01`: 7 tests and `P01_GATE_TESTS_PASS`
- `tools/validate-p02`: `P02_VALIDATION_PASS`
- `tools/test-validate-p02`: 12 tests and `P02_VALIDATION_TESTS_PASS`
- `tools/generate-p02-corpus --check`:
  `P02_CORPUS_GENERATION_CHECK_PASS`

The inherited P01 gate ran format checking, Clippy with warnings denied, all
workspace tests with all features, and all-target workspace builds. The
`nlu-data` suite passed 10 unit tests and 6 integration tests. The integration
suite performs two complete 11,850-record builds, including one through the
actual CLI, and exercises selective source removal.

The first acceptance attempt rejected three Clippy warnings. The array-chunk
idiom and nested split checks were changed mechanically, and the entire gate
was rerun successfully. No candidate had been frozen, so this was not a
candidate-remediation round.

## Command Contract

The built binary successfully executed:

```text
nlu-data verify --manifest <manifest> --root <root>
nlu-data import --manifest <manifest> --root <root> --output <imported>
nlu-data normalize --input <imported> --output <normalized>
nlu-data validate --input <normalized>
nlu-data split --input <normalized> --output <split>
nlu-data compile --input <split> --output <compiled>
nlu-data remove-source --input <split> --source-id <id> --output <filtered>
```

Each command returned its `NLU_DATA_*_PASS` sentinel. Tests also executed
`fetch` with and without `--allow-fetch`: the unauthorized call failed without
creating output, while the authorized local copy verified byte for byte.

The CLI rejects missing, duplicate, unknown, and non-UTF-8 options. The source
and every stage are immutable inputs; destinations must not already exist and
are promoted only after complete writes.

## Admission And Negative Tests

The source verifier binds the strict manifest to 14 listed artifacts, the
Apache-2.0 license bytes, accepted ADR status, aggregate bytes, and aggregate
SHA-256. Import invokes that verifier in-process before creating a promoted
stage.

Negative tests cover:

- unknown and missing manifest fields;
- substituted admission status, owner, immutable version, license, review
  set, path, artifact bytes, size, and SHA-256;
- non-commercial, no-derivatives, research-only, and missing-license values;
- path traversal and symlink substitution;
- malformed, floating-point, duplicate-key, and noncanonical JSON;
- missing record provenance, wrong source ID, duplicate record identity, and
  `FIXTURE_TECNICA` in linguistic data;
- family leakage across frozen partitions;
- implicit fetch and destination reuse.

The repository gate additionally fixes the `nlu-data` dependency set to Serde
and Serde JSON, rejects production network, process, ambient-environment,
wall-time, entropy, unordered-collection, and mutable-global APIs, and checks
all three published data schemas as closed version-1 objects.

## Reproduction

Two distinct temporary roots ran the complete CLI pipeline from the same
verified source. `cmp -s` reported equality for imported, normalized, split,
compiled package, and package-manifest bytes.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| Imported records | 18,395,269 | `dd3bdf856709a82731f0fb288aa79a2514b15f5660424ab2d561d8fb0c31236f` |
| Normalized records | 18,395,269 | `dd3bdf856709a82731f0fb288aa79a2514b15f5660424ab2d561d8fb0c31236f` |
| Split records | 18,476,074 | `e80f33cc4e3fdc40336b26681d9a6d785a71f0c29448f7e7f5387ec46419105c` |
| Compiled package | 18,511,641 | `2d76e521b09b37dadba63487e62486193cd2ad5217c70cc8944ee0294deb5905` |
| Package manifest | 636 | `598a2e960a4b2beb91332ab6d333797bfb5afd68b96acf76e73650cba5a13f2f` |

The package manifest records 11,850 records, the sorted source ID, partition
counts, source-manifest hash, split-record hash, package byte count, and
package hash. Products contain no timestamp, absolute path, locale-derived
value, random identifier, or unordered mapping.

## Selective Removal

Removing `project-authored-synthetic-ptbr-v1` produced a valid zero-record
filtered stage. Recompilation produced a 17-byte package with empty
`source_ids` and `partition_counts`, and SHA-256
`04420a1af662b2e5554e3968e51c27951441299363f4ce29a1f16d266203855c`.
The integration test also scans the result and finds no remaining source-ID
bytes.

## Review State

This is executor validation of the first minimally acceptable implementation,
not an independent post-phase review. The user directed the executor to skip
the final review after a successful run and move on. No independent review
result is fabricated, and no optional compression, downloader, format
expansion, or performance refinement follows.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks` created the clean source root
`/private/tmp/nlu-p03-repro.7RhNGh/repo`. It checked out candidate
`80672238116c125a4174329ce03e67ac88f42d5f` with tree
`a5296aa0e7d2f4013974a8b9fbce2bd5650802d8` and an empty worktree status.
Representative source, corpus, and copied toolchain files had different inode
identities from the candidate worktree.

Because the verified `.tools` directory is an ignored ambient build input, it
is correctly absent from a Git clone. The already hash-pinned Rust 1.98.0
toolchain was copied into the clean root with independent inodes. No dependency
or network fetch occurred.

Inside that clone:

- `tools/validate-p01` returned `P01_GATE_PASS`;
- `tools/test-validate-p01` returned `P01_GATE_TESTS_PASS`;
- `tools/validate-p02` returned `P02_VALIDATION_PASS`;
- `tools/test-validate-p02` returned `P02_VALIDATION_TESTS_PASS`;
- `tools/generate-p02-corpus --check` returned
  `P02_CORPUS_GENERATION_CHECK_PASS`;
- the explicit import, normalize, split, and compile CLI sequence returned all
  four command pass sentinels.

The reproduced split SHA-256 was
`e80f33cc4e3fdc40336b26681d9a6d785a71f0c29448f7e7f5387ec46419105c`.
The reproduced package contained 18,511,641 bytes with SHA-256
`2d76e521b09b37dadba63487e62486193cd2ad5217c70cc8944ee0294deb5905`,
and `cmp -s` confirmed equality with the pre-freeze package. This is
candidate-controlled deterministic reproduction, not independent review.
