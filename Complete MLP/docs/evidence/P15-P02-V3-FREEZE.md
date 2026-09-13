# P15 P02-v3 pre-remediation freeze

Date: 2026-09-11

Result: `PASS`

Status: `FROZEN_PRE_REMEDIATION`

Checkpoint commit:
`a3c0a273f0d66d4bc1813fb12472dba7815dd178`

Checkpoint tree:
`f2da7663c2321443633dd7496bd5db5b4987b1b3`

This self-resolving checkpoint records the fresh deterministic Apache-2.0
`PROJECT_AUTHORED_SYNTHETIC` PT-BR P02-v3 qualification lineage authorized by
ADR-0048 and the user. The writer did not commit. The executor will record the
resulting exact commit and tree in a follow-up governance-only binding without
changing the freeze subject. Any subject change invalidates this inventory and
requires regeneration and revalidation.

## Authorization and chronology

- Parent authorization commit:
  `d2c34476f660f6bcaf0f193fca67d084b4b4a0b2`
- Parent authorization tree:
  `d16c656666e4d46d653479e86e16e8a94079f2cf`
- Exhausted-round continuation authorization commit:
  `68f004eded59b5f223a218516bf38b9cbd36872c`
- Exhausted-round continuation authorization tree:
  `2c64dd1e4a85618fb59bc2d55aa125907970ce80`
- Chronology:
  `AFTER_ADR_0048_AUTHORIZATION_BEFORE_REMEDIATION_IMPLEMENTATION`
- Behavior-change boundary: `BEFORE_REMEDIATION_IMPLEMENTATION`
- Heldout post-freeze access: `SEALED_AGGREGATE_RUNNER_ONLY`
- Performance post-freeze access: `SEALED_AGGREGATE_RUNNER_ONLY`
- Suite post-freeze access: `SEALED_AGGREGATE_RUNNER_ONLY`
- License: `Apache-2.0`
- Claim scope: `internal_conformance_only`
- Self-oracle use: prohibited

## Lineage identities

- Source ID: `project-authored-synthetic-ptbr-p15-v3-qf`
- Corpus version: `3.0.0`
- Generator ID: `p02-qualification-generator-v3-qf`
- Generator version: `3.0.0`
- Specification ID:
  `p02v3qf-spec-32198119a097794a34e11637468e079d30c19f23f0b71a91ebf72b214c26d205`
- Specification SHA-256:
  `32198119a097794a34e11637468e079d30c19f23f0b71a91ebf72b214c26d205`
- Generator artifact ID:
  `p02v3qf-generator-3115ad207fafb4f3de34c037d9091f7e11197182e107baa75bcf9f2f273ca97d`
- Generator SHA-256:
  `3115ad207fafb4f3de34c037d9091f7e11197182e107baa75bcf9f2f273ca97d`
- Deterministic algorithm:
  `P02V3_SHA256_COUNTER_PERMUTATION_V1`
- Canonical identity encoding:
  `RECURSIVE_LEXICOGRAPHIC_KEYS_UTF8_JSON_V1`

## Corpus aggregate inventory

Release and suite records are represented only by whole-artifact aggregates.

| Path under `data/project-authored/p02-v3/` | Records | Bytes | SHA-256 | Whole-artifact identity |
| --- | ---: | ---: | --- | --- |
| `train.jsonl` | 960 | 1828513 | `076e4f58ed3f6d930c148ddc47943deb83a1501e2a942a80f1f9fad25465611d` | `p02v3qf-artifact-076e4f58ed3f6d930c148ddc47943deb83a1501e2a942a80f1f9fad25465611d` |
| `development.jsonl` | 960 | 1832846 | `7852c0b1f7e7edc430bcff4107291e25c418993b38e190f8c47e098a45fc777c` | `p02v3qf-artifact-7852c0b1f7e7edc430bcff4107291e25c418993b38e190f8c47e098a45fc777c` |
| `heldout.jsonl` | 4800 | 9162977 | `f83aa6b2f8679419b1ee54eb61e636b6548315260c07a900162996f7c2252045` | `p02v3qf-artifact-f83aa6b2f8679419b1ee54eb61e636b6548315260c07a900162996f7c2252045` |
| `performance.jsonl` | 4800 | 9207940 | `da49417068d9982a8f422c4a09bf17a64a5c62caf4fae4bf7226fc5d33946b6a` | `p02v3qf-artifact-da49417068d9982a8f422c4a09bf17a64a5c62caf4fae4bf7226fc5d33946b6a` |
| `suites/safety-sensitive.jsonl` | 5 | 6795 | `bc52daa8c5035ccbd4eed0b6f51575d2d14cd03b64096e0868cabf02efabc9b5` | `p02v3qf-artifact-bc52daa8c5035ccbd4eed0b6f51575d2d14cd03b64096e0868cabf02efabc9b5` |
| `suites/contradiction.jsonl` | 5 | 6740 | `d7e561f12a77c962c4b8133086730053458edd841dd3c02804880ef6cbce7e62` | `p02v3qf-artifact-d7e561f12a77c962c4b8133086730053458edd841dd3c02804880ef6cbce7e62` |
| `suites/ambiguity.jsonl` | 5 | 6647 | `1a78a023a993432244ef1c36c9706274e2c912c1131822815863119c2386538e` | `p02v3qf-artifact-1a78a023a993432244ef1c36c9706274e2c912c1131822815863119c2386538e` |
| `suites/stale-state.jsonl` | 5 | 6812 | `429c73211cdaf3edc24e3a4d0721b9ce611ad6172540b54ff8e37ab4386f422c` | `p02v3qf-artifact-429c73211cdaf3edc24e3a4d0721b9ce611ad6172540b54ff8e37ab4386f422c` |
| `suites/explicit-negative.jsonl` | 7 | 9552 | `4808add1aa616036d2fb4082dcdd5cd77cd78feaeeed302793ff136d9997d15f` | `p02v3qf-artifact-4808add1aa616036d2fb4082dcdd5cd77cd78feaeeed302793ff136d9997d15f` |
| `manifest.json` | 1 | 23210 | `6f9e186db0dcda321cf7895b1043d98b1fa23dc5713537ab47154c0e28bec88d` | `p02v3qf-manifest-6f9e186db0dcda321cf7895b1043d98b1fa23dc5713537ab47154c0e28bec88d` |
| `specification.json` | 1 | 48352 | `32198119a097794a34e11637468e079d30c19f23f0b71a91ebf72b214c26d205` | `p02v3qf-spec-32198119a097794a34e11637468e079d30c19f23f0b71a91ebf72b214c26d205` |

The nine corpus partitions contain 11,547 records in total: 960 train, 960
development, 4,800 heldout, 4,800 performance, and 27 fail-closed suite
records. The nine JSONL artifacts total 22,068,822 bytes. With the manifest and
specification, the data lineage totals 22,140,384 bytes across 11 files.

## Tool inventory

| Path | Bytes | SHA-256 |
| --- | ---: | --- |
| `tools/generate-p02-v3-corpus.rb` | 60446 | `3115ad207fafb4f3de34c037d9091f7e11197182e107baa75bcf9f2f273ca97d` |
| `tools/test-generate-p02-v3-corpus.rb` | 6709 | `a3ca3d3141d32ba25b796c31f125a6d98985376d6dab9282a245fceeeb0efe80` |
| `tools/validate-p02-v3.rb` | 45101 | `2c44199d94becc8e8c199287bf33211ba72be2547fa8d04cd8bef1780bc6e9d4` |
| `tools/test-validate-p02-v3.rb` | 31504 | `e49deec720bf8a0b5e545cac43eaff0bb0e103c216169dc93059e215540189a2` |

The freeze subject is the 11 data-lineage files plus these four tool files.
This checkpoint file is excluded from its own SHA-256 inventory to avoid a
self-reference. The governance-only binding above identifies the immutable
commit and tree that first contain the reviewed subject.

## Independent review

The final read-only reviewer independently identified the 17-file candidate
as
`851d7e9be8647b1cf7b0be9a98e7a6c7d3b7cf886cb704dc1cd1384e594f1b0`,
reproduced the syntax, deterministic-generation, aggregate-validation,
source-inventory, blob-binding, extensionless-path, Git-configuration,
bounded-capture, and marker regressions, and reported zero P0 through P3
findings.

Result: `PASS`

Report: `docs/reviews/P15/p02-v3-freeze-final.md`

The two valid failed predecessor reviews and their complete remediation are
recorded in
`docs/evidence/P15-P02-V3-USR047-REVIEW-REMEDIATION.md`.

## Verified controls

- Strict UTF-8 JSON and JSONL parsing rejects duplicate keys, malformed JSON,
  CR line endings, blank rows, missing final LF, oversized rows, oversized
  artifacts, excessive record counts, symlink leaves or ancestors, resolved
  path escapes, and unexpected path sets.
- Regeneration is byte-for-byte deterministic from the versioned
  specification and generator.
- All nine partitions are pairwise disjoint for utterances, case IDs,
  generator-record IDs, canonical semantic IDs, family identities, and
  canonical semantic-payload identities.
- Every heldout and performance intent stratum has 240 records, exceeding the
  required minimum of 237, and performance coverage matches heldout coverage
  on every declared dimension except the intentionally partitioned family
  identity.
- Corpus records reject fixture and placeholder markers. Technical self-tests
  use only `FIXTURE_TECNICA` temporary mutation data and do not load canonical
  corpus records.
- V3 artifact identities differ from every corresponding v2 manifest-declared
  artifact identity. No v2 heldout, performance, or suite record bytes were
  used for this comparison.
- Source-change confinement is independent of language, extension, lexical
  release-path recognition, and I/O syntax recognition. Every inventoried
  project path must retain both the pathname and Git blob identity recorded
  in the immutable authorization-parent commit. Any new or changed path is
  rejected unless it is one of 40 exact future mutable capability paths
  carrying `P02V3_FUTURE_MUTABLE_SOURCE_BOUNDARY_V1`, or an exact release
  boundary carrying `P02V3_RELEASE_LOADER_BOUNDARY_V1`. All 40 mutable paths
  are conservatively treated as I/O-capable; there is no syntax-classified
  subset. Unchanged authorization-parent blobs need no retrospective marker,
  while every new or changed blob does. A regression replaces an existing
  parent path with a reader that reconstructs the sealed path from numeric
  bytes, aliases both recognized bounded-read abstractions so the syntax
  matcher returns false, and invokes the aliases; the changed blob is still
  rejected. Separate fixtures prove unchanged parent blobs pass, changed
  predeclared non-I/O blobs fail without the marker and pass with it,
  sub-token reconstruction outside the inventory is rejected, and an
  extensionless executable project source is inventoried and rejected.
- The immutable source-inventory exclusion list contains only ambient host
  metadata, admitted local tool/cache roots, generated Python caches, the
  prohibited steering attestation, governed data, documentation, generated
  release output, and root build output:
  `.DS_Store`, `.cargo-home/**`, `.mypy_cache/**`, `.pytest_cache/**`,
  `.tools/**`, `**/.DS_Store`, `**/__pycache__/**`, `**/*.pyc`,
  `STEERING-NLU-PTBR-SOL-MAX.md`, `data/**`, `docs/**`, `release/**`, and
  `target/**`.
- Source inventory uses exact `/usr/bin/git`, disables system and global
  configuration and replacement objects, command-overrides repository-local
  `core.excludesFile`, binds an explicit root `.git` directory and root
  worktree, and does not apply `--exclude-standard`. Regressions prove that
  local `core.excludesFile`, `.git/info/exclude`, and a redirected local
  `core.worktree` cannot hide an untracked project source. A dual-pipe
  streaming capture drains stdout and stderr concurrently, retains at most
  each configured limit plus one byte, and terminates and reaps the child on
  overflow or capture failure. The stdout limit is 4,194,304 bytes, the
  stderr limit is 65,536 bytes, and any stderr is rejected. Strict NUL
  framing, UTF-8, relative-path, traversal, duplicate, 50,000-path, and
  output-size checks complete before source scanning.
- Subprocess fixtures prove stdout and stderr one-byte overflow rejection,
  nonzero-exit rejection, valid bounded NUL output, and concurrent 131,072-byte
  stdout/stderr draining without deadlock.
- Reusable containment checks cover canonical specification, manifest,
  artifact, generator, and scanned source paths. Every component beneath the
  selected root must be non-symlink, and each resolved file must remain under
  the resolved root. Fixture tests exercise ancestor-directory symlink
  escapes for corpus and source reads.
- Train and development are inspectable. Heldout, performance, and all five
  suites are aggregate-only for the executor and remediation agents.

## Reproducible checks

| Command | Result |
| --- | --- |
| `ruby -c tools/generate-p02-v3-corpus.rb` | `Syntax OK` |
| `ruby -c tools/test-generate-p02-v3-corpus.rb` | `Syntax OK` |
| `ruby -c tools/validate-p02-v3.rb` | `Syntax OK` |
| `ruby -c tools/test-validate-p02-v3.rb` | `Syntax OK` |
| `ruby tools/test-generate-p02-v3-corpus.rb` | 13 tests passed; `P02_V3_CORPUS_TESTS_PASS` |
| `ruby tools/test-validate-p02-v3.rb` | 32 tests passed; `P02_V3_VALIDATION_TESTS_PASS` |
| `ruby -w tools/test-generate-p02-v3-corpus.rb` | 13 tests passed without warnings |
| `ruby -w tools/test-validate-p02-v3.rb` | 32 tests passed without warnings |
| `ruby tools/generate-p02-v3-corpus.rb --check` | `P02_V3_CORPUS_GENERATION_CHECK_PASS` |
| `ruby tools/validate-p02-v3.rb` | `P02_V3_VALIDATION_PASS` |
| `ruby tools/validate-p02-v3.rb --aggregate-report` | Aggregate inventory above; `P02_V3_VALIDATION_PASS` |
| `git diff --check` | pass |

## Access attestation

The writer did not open, grep, print, parse, copy, or otherwise read any v2
`heldout.jsonl`, `performance.jsonl`, or `suites/*` record bytes. Only the
authorized v2 specification/generator inputs and manifest-declared aggregate
identities were used for prior-lineage separation.

No generated v3 heldout, performance, or suite record contents were printed or
inspected outside the marked generator and aggregate-validation boundary.
Commands and this evidence disclose only counts, byte sizes, SHA-256 values,
whole-artifact identities, and lineage-level identities. No product NLU
behavior was implemented, inspected, tuned, executed, or reviewed.
