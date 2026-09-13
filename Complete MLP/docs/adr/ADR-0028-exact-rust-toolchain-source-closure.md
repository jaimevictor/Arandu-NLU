# ADR-0028: Exact Rust Toolchain Source Closure

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P15
- Supersedes: ADR-0027 only for the Rust toolchain source-license evidence

## Context

License review of P13 subject
`89bd61750795301b7975449e7fa29e75b189bf36` found that Rust's bound
whole-distribution `COPYRIGHT.html` includes `notify 8.2.0` solely under
`CC0-1.0`. CC0 is not an OSI-approved software license. The notice marks that
package outside `libstd`, but the candidate did not independently prove it
outside the selected `rustc`, `clippy-driver`, `librustc_driver`, LLVM linker,
LLVM runtime, and target-sysroot source closure.

## Decision

Bind the official Rust 1.98.0 source archive identified by the already-admitted
dated channel manifest. Offline validation MUST:

- verify the channel manifest and source archive by exact byte count and
  SHA-256, and bind both to source commit
  `88d9e12ae178fab0fb5cc050a94da85685d449ea`;
- extract only an exact allowlist of source manifests, lockfiles, and license
  roots with the already-admitted `bsdtar`;
- prove `compiler/rustc`, `src/tools/clippy`, `rustc_driver`, and
  `rustc_driver_impl` resolve through the source root lock, where `notify` is
  absent;
- prove the target sysroot resolves through the library lock and complete
  library notice, where a sole CC0 license is absent;
- classify all 535 registry packages in the conservative compiler/Clippy lock
  universe from `vendor` and all 30 selected sysroot registry packages from
  `library/vendor` by exact lock tuple, generated `Cargo.toml`,
  `.cargo-checksum.json`, and complete legal-file inventory;
- separately prove the four selected rustc/Clippy roots close over 397
  packages, including 317 registry packages, and reject bundled source under
  non-OSI `BSD-4-Clause-UC` or `curl` terms when its package is outside that
  active graph;
- elect only an OSI-approved branch of each selected Cargo license expression,
  with exact OSI and LLVM-exception metadata read from SPDX
  `license-list-XML` commit
  `24b4ed8996b5f8d3f91e51961b46803e9e356814`;
- bind the LLVM and LLD Apache-2.0-with-LLVM-exception license roots;
- prove the sole `CC0-1.0`-only package in the complete Rust notice is
  `notify 8.2.0`, that it appears in the separate rust-analyzer lock, and that
  `notify` is not installed or selected; treat the installed
  `rust-analyzer-proc-macro-srv` helper as unselected and unexecuted rather than
  claiming it is absent; and
- reject source archive, member, lock, package-boundary, notice, and selected
  tool-set substitutions.

The broad Rust notice remains bound as a conservative attribution inventory,
but it is no longer treated as proof that every package it lists is active.
The verifier binds 1,593 complete-toolchain notice records, 148
standard-library notice records, 990 compiler/Clippy lock-universe legal
files, and 61 sysroot legal files. Nine nested or nonstandard files receive
exact reviewed dispositions. `capstone`, `capstone-sys`, `curl-sys`,
`libgit2-sys`, and `lzma-sys` are present for conservative lock audit but
unreachable from the selected roots. No CC0, `BSD-4-Clause-UC`, or
`curl`-licensed software is admitted.

## Minimum Acceptance And Pass Limit

The latest correction is the blocker-only closure authorized by `USR-030`.
The source fetch, source closure, Noise evidence, and aggregate P13 gates must
pass before one frozen replacement receives all five source reviews and seven
phase reviews. The first passing subject checkpoints immediately. No optional
refinement or post-pass review follows.

## Consequences

The selected toolchain receives an exact, reproducible source and license
boundary. Uninstalled rust-analyzer source remains outside the project input
closure. Product, protocol, dependency, cryptographic implementation, and
linguistic bytes do not change.

## Rollback

Keep the transport runtime disabled and do not use the Rust toolchain for P13
validation if the source archive, selected member graph, or OSI-only closure
cannot be reproduced exactly.
