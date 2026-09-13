# P04 Unicode Validation Evidence

- Phase: `P04`
- Candidate: `cc579ca73ef1b9538338bb33ac11f5383c7ae8c4`
- Candidate tree: `482b798caa5674fbc5d703fdfb5a8b33d27e7794`
- Candidate round: 1 of 3
- Validation time: `2026-08-28T22:40:18Z`
- Reproduction time: `2026-08-28T22:43:15Z`
- Unicode version: `17.0.0`
- Normalization form: `NFC`
- Result: `PASS`

## Scope

P04 adds `lang-ptbr` as a real workspace library. It preserves the immutable
`RequestText`, stores NFC separately, maps normalized extended-grapheme units
to original half-open UTF-8 byte ranges, and enforces independent byte,
scalar, grapheme, and Unicode-word limits.

No PT-BR vocabulary, grammar, tokenization rule, model, training data, or
semantic behavior was added. The admitted Unicode files are technical
standards conformance data and are excluded from linguistic metrics.

## Executed Gates

The first complete acceptance run executed:

```text
tools/validate-p01
tools/validate-p04
tools/validate-p02
tools/test-validate-p02
tools/generate-p02-corpus --check
```

All returned their pass sentinels:

- `tools/validate-p01`: `P01_GATE_PASS`
- `tools/validate-p04`: `P04_GATE_PASS`
- `tools/validate-p02`: `P02_VALIDATION_PASS`
- `tools/test-validate-p02`: 12 tests and `P02_VALIDATION_TESTS_PASS`
- `tools/generate-p02-corpus --check`:
  `P02_CORPUS_GENERATION_CHECK_PASS`

Focused validation also executed:

```text
cargo test -p lang-ptbr --all-features
tools/validate-p01 --no-cargo
tools/test-validate-p01
tools/validate-p04 --no-cargo
tools/test-validate-p04
```

The Rust suite passed 13 tests. The P01 mutation suite passed 8 tests and the
P04 mutation suite passed 4 tests. The P01 full gate ran format checking,
Clippy with warnings denied, every workspace test with all features, and every
all-feature workspace target build entirely from the vendored source.

The first focused compile found four test-only comparisons that would have
required equality on a source-identity-bearing type. The assertions were
changed to compare typed errors without adding that invalid equality
implementation. No candidate had been frozen, and the complete acceptance run
then passed.

## Official Source Conformance

The immutable official UCD archive is Unicode 17.0.0
`UCD.zip`, 9,101,877 bytes, SHA-256
`2066d1909b2ea93916ce092da1c0ee4808ea3ef8407c94b4f14f5b7eb263d28e`.
Exact extracted bytes are bound by `tools/validate-p04`:

| Input | Rows | SHA-256 |
| --- | ---: | --- |
| `NormalizationTest.txt` | 20,034 | `5019ffd530751a741900c849c0e010332f142a3612234639bd200b82138a87db` |
| `GraphemeBreakTest.txt` | 766 | `e2d134d2c52919bace503ebb6a551c1855fe1a1faec18478c78fff254a1793ec` |
| `WordBreakTest.txt` | 1,944 | `1de23a75f37904abc7d206239ee8d34f8fdf0fb4ab32a7174dfbabbde25419b2` |

Every NFC invariant and idempotence case passed. Every extended-grapheme and
default-word-boundary vector passed. More than 19,000 policy-admissible
normalization rows also constructed `NormalizedText` and round-tripped their
full normalized span through the original source.

The Unicode License V3 bytes are retained with SHA-256
`e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96`.
Commercial use, modification, and redistribution with the notice are
permitted.

## Dependency Closure

The exact additions are:

| Package | Version | Archive SHA-256 |
| --- | --- | --- |
| `unicode-normalization` | 0.1.25 | `5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8` |
| `unicode-segmentation` | 1.13.3 | `c6f5d3c3b1bf09027a88a6bc961fc00497d651009560b5463668dc81b0fa87a8` |
| `tinyvec` | 1.12.0 | `bb4ebadaa0af04fab11ae01eb5f9fdb5f9c5b875506e210e71c07873528baa7f` |
| `tinyvec_macros` | 0.1.1 | `1f3ccbac311fea05f86f61904b462b55fb3df8837a366dfc601a0161d0532f20` |

Cargo generated 75 new per-file checksums; all passed. The complete lock now
contains 15 external packages and 549 checksum-bound package files. The four
new packages have no build script, runtime network, process, environment, or
ambient filesystem path.

`unicode-normalization` has five reviewed `from_u32_unchecked` sites limited to
Hangul composition/decomposition after closed arithmetic range checks. The
complete Unicode 17 normalization suite, including Hangul cases, passed.

## Normalization And Mapping

The policy is Unicode 17 NFC only. NFKC, case folding, accent removal,
transliteration, and confusable skeletons are absent. Tests prove that:

- decomposed accents compose while original bytes remain unchanged;
- canonical combining-mark reordering maps as one reversible unit;
- already-normalized input is idempotent;
- compatibility characters remain compatibility characters;
- accents remain present;
- Latin/Cyrillic and Latin/Greek lookalikes remain byte-distinct;
- normalized spans from another source identity are rejected;
- reversed, empty, overflowing, out-of-range, interior UTF-8, and
  interior-normalization-unit offsets are rejected.

Every accepted normalized span boundary is both a UTF-8 character boundary and
an original/normalized grapheme-unit boundary. Converting normalized to
original and back reproduces the exact source-bound normalized span.

## Policy And Limits

Every Unicode control scalar is rejected. The explicit Unicode 17
format/default-ignorable policy rejects soft hyphen, combining grapheme
joiner, bidi controls, zero-width joiners, variation selectors, tags,
fillers, byte-order mark, interlinear controls, and the recorded script/music
format ranges. No rejected scalar is silently deleted.

Boundary tests accept the exact limits and reject one over:

| Limit | Value |
| --- | ---: |
| Original UTF-8 bytes | 65,536 |
| Unicode scalar values | 32,768 |
| Extended grapheme clusters | 16,384 |
| Unicode words/tokens | 4,096 |

The independent benchmark word-count identifier is
`uax29-default-word-v1/unicode-17.0.0/unicode-segmentation-1.13.3`.

## Convergence And Review

Pre-candidate convergence pass 1 selected the official Unicode 17 source,
exact table-driven crate closure, NFC, grapheme-unit mapping, and four-limit
model. It passed minimum acceptance without redesign.

This is candidate round 1 of 3 and the first minimally acceptable baseline.
It is frozen immediately. Remaining rounds are available only for a reproduced
P0-P2 blocker; no optional folding, tailoring, source expansion, or
performance refinement follows.

The user directed the executor to skip the final review after a successful run
and move on. This is executor validation, not an independent post-phase
review. No independent review result is claimed or fabricated.

## Exact-Commit Reproduction

A local `git clone --no-hardlinks` created the clean source root
`/private/tmp/nlu-p04-repro.l1ATkj/repo`. It checked out candidate
`cc579ca73ef1b9538338bb33ac11f5383c7ae8c4` with tree
`482b798caa5674fbc5d703fdfb5a8b33d27e7794` and an empty worktree status.
Representative source, Unicode data, and copied toolchain files had different
inode identities from the candidate worktree.

The verified `.tools` directory is an ignored ambient build input and was
copied into the clone with independent inodes. No dependency or source fetch
occurred. Cargo used only the committed vendor directory with offline mode.

Inside that clone:

- `tools/validate-p01` returned `P01_GATE_PASS`;
- `tools/test-validate-p01` returned `P01_GATE_TESTS_PASS`;
- `tools/validate-p04` returned `P04_GATE_PASS`;
- `tools/test-validate-p04` returned `P04_GATE_TESTS_PASS`;
- `tools/validate-p02` returned `P02_VALIDATION_PASS`;
- `tools/test-validate-p02` returned `P02_VALIDATION_TESTS_PASS`;
- `tools/generate-p02-corpus --check` returned
  `P02_CORPUS_GENERATION_CHECK_PASS`.

The reproduced normalization, grapheme, and word source hashes matched the
candidate values exactly. This is candidate-controlled deterministic
reproduction, not an independent review.
