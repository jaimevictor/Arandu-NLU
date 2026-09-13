# P13 Historical Source-License Review

- Role: `source-license`
- Review instance: `01a050b6-f100-7e12-b8fd-149aef1f351f`
- Subject commit: `41ea528df9b6163a9a08a297d21c9c8f8c18b386`
- Subject tree: `3b518a172867f587614c0947c63e83cc7111f75e`
- Git archive SHA-256: `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`
- Mode: independent, read-only review
- Repository state during review: clean exact-subject worktree
- Network, sibling directories, Amazon-specific material, and unbound language
  sources: not used

## Scope

Primary evidence inspected from the frozen subject:

- `docs/adr/ADR-0028-exact-rust-toolchain-source-closure.md`
- `docs/evidence/P13-NOISE-SOURCES.yaml`
- `docs/evidence/TOOLCHAIN-PROVENANCE.yaml`
- `docs/clean-room/MATERIALS.yaml`
- `tools/p13-noise-evidence.rb`
- `tools/test-p13-noise-evidence.rb`

The review independently checked the Rust 1.98.0 source archive and channel
manifest identities, compiler/Clippy and sysroot lock closures, selected-root
reachability, nested legal-file discovery, Rust and LLVM license roots, SPDX
OSI and LLVM-exception records, complete Rust notices, excluded `notify`, and
rejection of BSD-4-Clause-UC, curl, CC0-only software, and BUSL mutations.

## Commands And Results

Identity:

```sh
git status --short
git rev-parse HEAD
git rev-parse '41ea528df9b6163a9a08a297d21c9c8f8c18b386^{tree}'
git archive --format=tar 41ea528df9b6163a9a08a297d21c9c8f8c18b386 | shasum -a 256
```

`git status --short` was empty. Commit, tree, and archive output matched the
identities above exactly.

Bound Rust inputs:

```sh
shasum -a 256 \
  /private/tmp/p13-rust-source/channel-rust-1.98.0.toml \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
wc -c \
  /private/tmp/p13-rust-source/channel-rust-1.98.0.toml \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
tools/p13-noise-evidence --skip-runtime
tools/test-p13-noise-evidence
```

The manifest reproduced 898,637 bytes and SHA-256
`3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a`.
The source archive reproduced 244,440,040 bytes and SHA-256
`271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e`.
The committed validator emitted `P13_NOISE_SOURCE_EVIDENCE_PASS`; the mutation
suite emitted `P13_NOISE_EVIDENCE_TESTS_PASS`.

Lock and rights checks reproduced:

- 660 compiler/Clippy lock packages;
- 397 packages reachable from `rustc-main`, `rustc_driver`,
  `rustc_driver_impl`, and `clippy`;
- 317 reachable registry packages;
- `capstone`, `capstone-sys`, `curl-sys`, and `libgit2-sys` were unreachable;
- `notify` occurred zero times in compiler/Clippy and sysroot locks and once in
  the excluded rust-analyzer lock;
- the complete Rust notice had one CC0-only record, `notify-8.2.0`, marked
  outside `libstd`;
- no installed `notify` path was found; and
- injecting `curl-sys` into `rustc-main` dependencies was rejected with
  `P13 Rust active lock graph inventory differs`.

SPDX commit `24b4ed8996b5f8d3f91e51961b46803e9e356814` reproduced tree
`b96913f1e33b03c3da8666514f67452c657e0a17`. Its exact XML marked
Apache-2.0 as OSI approved, bound `LLVM-exception` as an exception, and marked
BSD-4-Clause-UC and curl as not OSI approved. The LLVM and LLD license roots
reproduced SHA-256 values
`8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee`
and
`f7891568956e34643eb6a0db1462db30820d40d7266e2a78063f2fe233ece5a0`.
The coherent BUSL Cargo-license mutation in
`tools/test-p13-noise-evidence.rb` was rejected.

## Counterexample

The exact archive contains legal and attribution files that the discovery
predicate does not recognize:

```sh
/usr/bin/ruby --disable-gems -Itools -rp13-noise-evidence -e \
  'puts P13NoiseEvidence.rust_registry_legal_file_path?("THIRD_PARTY.txt");
   puts P13NoiseEvidence.rust_registry_legal_file_path?("capstone/CREDITS.TXT")'
```

Both results were `false`.

The bound `.cargo-checksum.json` files nevertheless list:

- `vendor/capstone-0.14.0/THIRD_PARTY.txt`, 1,752 bytes, SHA-256
  `c4489e73a9f2ec47bbb76ea770480e77c4446cfb801ae6c739bca91ae4ff3656`;
- `vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT`, 3,144 bytes, SHA-256
  `b4baaceb3ad09b94b0925c5bab1238562f8fc202343141e1e0618db51d21a535`.

Direct `bsdtar -xJOf` inspection showed that `THIRD_PARTY.txt` contains the
complete BSD-3-Clause grant and attribution for bundled Capstone code, while
the package manifest declares only MIT. `CREDITS.TXT` records contributor
provenance. The committed validator still passed because its legal-file
predicate recognizes license, notice, author, and contributor tokens but not
`THIRD_PARTY` or `CREDITS`.

## Findings

- P0: none.
- P1: the claimed complete 986-file compiler/Clippy lock-universe legal
  inventory is incomplete. ADR-0028 requires complete legal-file
  classification for all 535 registry packages, but the two checksum-bound
  files above are omitted from extraction, inventory hashes, dispositions,
  materials, provenance relations, and mutation coverage. Their packages being
  unreachable protects the selected graph but does not satisfy the mandatory
  conservative lock-universe evidence contract.
- P2: none.
- P3: none.

FAIL
