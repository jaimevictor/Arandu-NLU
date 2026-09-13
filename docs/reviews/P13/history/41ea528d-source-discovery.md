# P13 Source Discovery Historical Review

- Role: `source-discovery`
- Review instance: `01a050b7-095a-72f0-88a3-bce91bb9a974`
- Review date: `2026-08-30`
- Subject commit: `41ea528df9b6163a9a08a297d21c9c8f8c18b386`
- Subject tree: `3b518a172867f587614c0947c63e83cc7111f75e`
- Subject archive SHA-256: `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`
- Mode: independent, read-only, offline
- Verdict: `FAIL`

## Scope

The review independently discovered source, license, attribution, and notice
surfaces in the exact bound Rust 1.98.0 source archive and the selected Noise
projection. It examined:

- nested and non-prefix legal filenames, casing, and extensions;
- bundled third-party trees;
- package manifests and `.cargo-checksum.json` inventories;
- complete Rust toolchain and standard-library notices;
- the 535-package conservative compiler/Clippy registry universe;
- the four-root active graph and the separate sysroot lock; and
- all 23 selected Noise crate archives and their projected legal files.

The review did not use the network, sibling directories, Amazon or internal
material, unbound language inputs, or another engine. No repository file was
changed during the review. Temporary mutation tests operated only in memory or
under the system temporary directory.

## Identity Evidence

Commands:

```text
git rev-parse HEAD 'HEAD^{tree}'
git archive --format=tar HEAD | shasum -a 256
git status --short
shasum -a 256 data/quarantine/rustc-1.98.0-src.tar.xz
shasum -a 256 data/quarantine/channel-rust-1.98.0.toml
wc -c data/quarantine/rustc-1.98.0-src.tar.xz
wc -c data/quarantine/channel-rust-1.98.0.toml
```

Results:

```text
commit=41ea528df9b6163a9a08a297d21c9c8f8c18b386
tree=3b518a172867f587614c0947c63e83cc7111f75e
git_archive_sha256=86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8
worktree_status=(empty)
rust_source_bytes=244440040
rust_source_sha256=271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e
channel_manifest_bytes=898637
channel_manifest_sha256=3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a
```

## Commands And Results

The exact archive was enumerated with:

```text
tar -tf data/quarantine/rustc-1.98.0-src.tar.xz
tar -tf data/quarantine/rustc-1.98.0-src.tar.xz |
  grep -E '/(THIRD_PARTY\.txt|CREDITS\.TXT|PACKAGERS|THANKS)$'
```

Each candidate and its package checksum metadata was read directly with
`tar -xOf`. Byte counts used `wc -c`; content hashes used
`shasum -a 256`; `.cargo-checksum.json` maps were parsed with Ruby `JSON`.
The recorded checksum for each of the four files matched its extracted bytes.

The implemented predicate was exercised directly:

```text
ruby -Itools -rp13-noise-evidence -e \
  'paths=%w[THIRD_PARTY.txt capstone/CREDITS.TXT xz-5.2/PACKAGERS xz-5.2/THANKS];
   paths.each { |p| puts "#{P13NoiseEvidence.rust_registry_legal_file_path?(p)}\t#{p}" }'
```

Result:

```text
false	THIRD_PARTY.txt
false	capstone/CREDITS.TXT
false	xz-5.2/PACKAGERS
false	xz-5.2/THANKS
```

The conservative and reachable graphs were parsed with
`P13NoiseEvidence.rust_lock_packages` and
`P13NoiseEvidence.rust_lock_reachable_packages`. Results:

```text
compiler_total=660
compiler_registry=535
compiler_registry_sha256=501587445a47f940c2c61b9ccb95bbfeacbe94109b30d14391786db7c40a2ab9
active_total=397
active_registry=317
active_registry_sha256=400397c713e3937e4885a40d44342468d65ada48b5475c79c02c531053b38980
active_subset_of_compiler=true
compiler_inactive_total=263
compiler_inactive_registry=218
sysroot_total=49
sysroot_registry=30
sysroot_registry_sha256=484a12bee10d6b350d061897ac1afb64596f09be3543ede4c83c2cfe74663ad3
```

`capstone 0.14.0`, `capstone-sys 0.18.0`, and `lzma-sys 0.1.20`
were present in the conservative compiler lock. All three were absent from
the four-root active graph and the sysroot lock.

Relevant gates and tests were run offline:

```text
P13_RUST_CHANNEL_MANIFEST=data/quarantine/channel-rust-1.98.0.toml \
P13_RUST_SOURCE_ARCHIVE=data/quarantine/rustc-1.98.0-src.tar.xz \
tools/p13-noise-evidence --skip-runtime

P13_RUST_CHANNEL_MANIFEST=data/quarantine/channel-rust-1.98.0.toml \
P13_RUST_SOURCE_ARCHIVE=data/quarantine/rustc-1.98.0-src.tar.xz \
tools/test-p13-noise-evidence

tools/test-p13-source-fetch
```

Results:

```text
P13_NOISE_SOURCE_EVIDENCE_PASS
P13_NOISE_PROJECTION_PASS
P13_NOISE_ADVISORY_PASS
P13_NOISE_RUNTIME_SKIPPED
P13_NOISE_CAPABILITY_ONLY_PASS
P13_NOISE_EVIDENCE_TESTS_PASS
P13_SOURCE_FETCH_TESTS_PASS
```

The complete notice parser reproduced 1,593 toolchain identities and license
records with one CC0-only record, plus 148 standard-library identities and
license records with no CC0-only record. The complete notice had package
entries for the affected crates, but did not contain the full Capstone BSD
grant from `THIRD_PARTY.txt` or the XZ license guidance from `PACKAGERS`.

The selected Noise scan reproduced:

```text
selected_archives=23
broad_legal_candidates=44
broad_legal_candidates_unlisted=0
listed_legal_files=44
retained_legal_files=44
omitted=0
```

Its only path under a bundled `vendor/` component was
`curve25519-dalek/vendor/ristretto.sage`, 28,745 bytes with SHA-256
`a2f4309ada0afa4156f5a660be4384a0f1f332c12f836199124f48e89310344d`;
the projection bound it and deleted the whole file as recorded.

## Four-File Counterexample

The subject claimed a complete 986-file compiler/Clippy legal inventory, but
the predicate in `tools/p13-noise-evidence.rb` selected only basenames
containing its fixed legal-word set or paths below exact `LICENSE` or
`LICENSES` directory components. The following checksum-bound files were
therefore invisible to extraction, inventory, and validation:

| Package archive path | Bytes | SHA-256 | Discovered surface |
| --- | ---: | --- | --- |
| `vendor/capstone-0.14.0/THIRD_PARTY.txt` | 1,752 | `c4489e73a9f2ec47bbb76ea770480e77c4446cfb801ae6c739bca91ae4ff3656` | Complete Capstone BSD grant and redistribution conditions |
| `vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT` | 3,144 | `b4baaceb3ad09b94b0925c5bab1238562f8fc202343141e1e0618db51d21a535` | Contributor attribution inventory |
| `vendor/lzma-sys-0.1.20/xz-5.2/PACKAGERS` | 8,595 | `8ab0db1c1bf19383b6fd4e7f3fc1a627f7e4d44119fb019469644131df99c0e2` | Explicit public-domain and GPLv2+ license guidance |
| `vendor/lzma-sys-0.1.20/xz-5.2/THANKS` | 2,673 | `bcb2f3d036e823232e43706850e07bf8a493c49798354c4c97b2f2b15bf64a68` | Contributor attribution inventory |

All four paths and hashes were present in their packages'
`.cargo-checksum.json` maps. None was present in the claimed legal-file
inventory or reviewed legal-file dispositions.

An additional in-memory mutation inserted a correctly hashed
`THIRD_PARTY.txt` into fixture checksum metadata, recomputed the checksum
inventory, and intentionally left the legal inventory unchanged. Direct
validation returned:

```text
predicate_THIRD_PARTY=false
checksum_contains_THIRD_PARTY=true
legal_inventory_contains_THIRD_PARTY=false
validator_accepted=true
```

The passing baseline gate and accepted mutation establish a verifier blind
spot, not merely stale documentation.

## Findings

- P0: none.
- P1: none.
- P2: the mandatory complete conservative-lock legal and attribution
  inventory is false. Four checksum-bound surfaces are excluded by the
  shared discovery predicate, and the validator accepts that omission.
  Affected packages are inactive, so this is not classified as an active
  non-OSI admission or P1 execution-path defect.
- P3: none.

ADR-0028 requires every registry package in the 535-package conservative
compiler/Clippy universe to be classified from exact lock tuples, manifests,
checksums, and a complete legal-file inventory. Inactivity does not waive that
evidence requirement. The frozen subject therefore cannot pass independent
source discovery.

FAIL
