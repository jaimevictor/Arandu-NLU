# P13 Historical Source Quality And Security Review

- Role: `source-quality-security`
- Review instance: `01a050b7-0d28-7db2-bde7-f59b9214258a`
- Review date: `2026-08-30`
- Subject commit: `41ea528df9b6163a9a08a297d21c9c8f8c18b386`
- Subject tree: `3b518a172867f587614c0947c63e83cc7111f75e`
- Subject archive SHA-256:
  `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`
- Mode: independent, read-only, offline historical review

This report records only the immutable subject above. The reviewer did not
inspect sibling directories, use network access, use Amazon/internal material,
or admit unprovenanced linguistic material. Repository source remained
unchanged during the review; validation outputs were confined to temporary or
ignored generated locations.

## Scope

The review audited:

- exact repository, Rust source archive, package, lock, selected-source, and
  generated-projection boundaries;
- direct `rustc`, `clippy-driver`, linker, runtime-library, and sysroot
  selection and checksums;
- static and aggregate Cargo-execution prohibition;
- command-window and preexisting/generated-artifact guards;
- active lock reachability, inactive bundled packages, excluded
  `rust-analyzer-proc-macro-srv`, and `notify`;
- archive-member, path, symlink, hard-link, ownership, ancestor, and output
  layout safety;
- capability-only versus product-runtime admission claims; and
- exact RustSec advisory evidence and its stated limitation.

Primary paths inspected included:

- `docs/adr/ADR-0028-exact-rust-toolchain-source-closure.md`
- `docs/clean-room/MATERIALS.yaml`
- `docs/evidence/P13-NOISE-SOURCES.yaml`
- `docs/evidence/TOOLCHAIN-PROVENANCE.yaml`
- `tools/p13-noise-evidence.rb`
- `tools/p13-rustc-driver.rb`
- `tools/validate-p13.rb`
- their P13 test wrappers and test implementations

## Identity And Reproduced Commands

The following read-only identity checks reproduced the supplied subject:

```sh
git rev-parse HEAD 'HEAD^{tree}'
git archive --format=tar 41ea528df9b6163a9a08a297d21c9c8f8c18b386 |
  shasum -a 256
git archive --format=tar 41ea528df9b6163a9a08a297d21c9c8f8c18b386 |
  wc -c
git status --short
git diff --check \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386^ \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386
```

Results:

- commit `41ea528df9b6163a9a08a297d21c9c8f8c18b386`;
- tree `3b518a172867f587614c0947c63e83cc7111f75e`;
- archive size `35051520`;
- archive SHA-256
  `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`;
- empty review-time status; and
- no `git diff --check` diagnostics.

The relevant P13 gates and tests were executed:

```sh
tools/test-p13-rustc-driver
tools/test-p13-source-fetch
tools/test-p13-noise-evidence
tools/p13-noise-evidence --skip-runtime
tools/p13-noise-evidence
tools/test-validate-p13
tools/validate-p13 --no-cargo --review-candidate
```

Results included:

- `P13_RUSTC_DRIVER_TESTS_PASS`;
- `P13_SOURCE_FETCH_TESTS_PASS`;
- `P13_NOISE_EVIDENCE_TESTS_PASS`;
- source, projection, advisory, direct-test, direct-Clippy, and
  capability-only checks passing;
- `P13_GATE_TESTS_PASS`; and
- `P13_REVIEW_CANDIDATE_PASS`.

The pinned Rust source artifact was independently checked:

```sh
shasum -a 256 \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
stat -f '%z %N' \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
```

It was `244440040` bytes with SHA-256
`271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e`,
matching the evidence ledger.

## Counterexamples

### Dependency-Reachability Substitution

The reviewer parsed the source archive's root and library locks in memory,
appended the unique `curl-sys` package reference to the parsed `clippy`
dependency list, and called
`P13NoiseEvidence.validate_rust_active_lock_graph` against the recorded
active graph.

Result:

```text
DEPENDENCY_REACHABILITY_SUBSTITUTION_REJECTED: P13 Rust active lock graph inventory differs
```

This selected dependency-reachability substitution failed closed.

### Legal-Inventory False Acceptance

ADR-0028 required the conservative compiler/Clippy lock universe to classify
all 535 registry packages by exact tuple, generated manifest,
`.cargo-checksum.json`, and complete legal-file inventory. The verifier's
`rust_registry_legal_file_path?` classifier accepted conventional
`AUTHORS`, `COPYING`, `COPYRIGHT`, `LICENCE`, `LICENSE`, `NOTICE`, and
`UNLICENSE` names or files under a license-named directory, but did not accept
`THIRD_PARTY.txt` or `CREDITS.TXT`.

The following archive-member checks were reproduced:

```sh
bsdtar -tf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  '*/vendor/capstone-0.14.0/THIRD_PARTY.txt'
bsdtar -tf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  '*/vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT'
bsdtar -xOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/capstone-0.14.0/THIRD_PARTY.txt |
  shasum -a 256
bsdtar -xOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/capstone-0.14.0/THIRD_PARTY.txt |
  wc -c
bsdtar -xOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT |
  shasum -a 256
bsdtar -xOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT |
  wc -c
```

Results:

- `vendor/capstone-0.14.0/THIRD_PARTY.txt` was `1752` bytes with SHA-256
  `c4489e73a9f2ec47bbb76ea770480e77c4446cfb801ae6c739bca91ae4ff3656`;
- its package `.cargo-checksum.json` recorded that exact hash;
- the file contained the full BSD-style Capstone third-party grant;
- `vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT` was `3144` bytes with
  SHA-256
  `b4baaceb3ad09b94b0925c5bab1238562f8fc202343141e1e0618db51d21a535`;
- its package `.cargo-checksum.json` recorded that exact hash;
- `rust_registry_legal_file_path?` returned `false` for both paths; and
- neither path appeared in `docs/evidence/P13-NOISE-SOURCES.yaml`.

Despite these omissions, `tools/p13-noise-evidence` accepted the recorded
986-file inventory. The verifier therefore did not substantiate the
normative claim that the lock-universe legal-file inventory was complete.

## Otherwise-Passing Controls

No additional blocking defect was reproduced:

- compiler/Clippy lock counts reproduced as 660 packages and 535 registry
  packages;
- selected active graph counts reproduced as 397 packages and 317 registry
  packages;
- sysroot lock counts reproduced as 49 packages and 30 registry packages;
- `notify` counts reproduced as zero in compiler/Clippy, zero in sysroot, and
  one only in the excluded rust-analyzer lock;
- the installed `rust-analyzer-proc-macro-srv` helper was checksum-bound,
  unselected, and unexecuted;
- exact `rustc`, `clippy-driver`, `ld64.lld`, `libLLVM.dylib`,
  `librustc_driver`, sysroot, driver, wrapper, notice, manifest, and source
  archive identities matched;
- the aggregate validator required `--no-cargo`, propagated `--no-cargo` to
  inherited gates, propagated `--no-evaluator` to P07 and
  `--no-reproduction` to P09, and the direct driver invoked only the selected
  compiler, Clippy, linker, test, and probe paths;
- private output-root, ancestor, immutable-input, expected generated-file,
  symlink, hard-link, ownership, mode, layout, size, and checksum guards
  behaved consistently with the recorded claims;
- all five exact matching RustSec advisories were read and their selected
  versions satisfied the recorded patched ranges; the evidence correctly
  limited this to the exact database rather than claiming no undisclosed
  vulnerability; and
- the successful macOS probe remained a capability result, with product
  runtime and native Linux admission explicitly deferred to P14.

## Findings

- P0: none.
- P1: none.
- P2: the compiler/Clippy legal-file classifier omitted at least
  `vendor/capstone-0.14.0/THIRD_PARTY.txt` and
  `vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT`, while the verifier and
  evidence claimed a complete lock-universe legal-file inventory. The primary
  omitted file contains a third-party license grant and is explicitly bound by
  package checksum metadata. Because the affected Capstone path was not
  reachable from the selected rustc/Clippy roots, this was an evidence
  completeness and review-integrity blocker rather than a demonstrated
  selected-runtime license violation.
- P3: none.

FAIL
