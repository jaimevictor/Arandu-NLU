# P13 Historical Source Provenance Review

- Role: `source-provenance`
- Review instance: `01a050b6-fa5b-7fe2-a199-3c0029868a40`
- Subject commit: `41ea528df9b6163a9a08a297d21c9c8f8c18b386`
- Subject tree: `3b518a172867f587614c0947c63e83cc7111f75e`
- Archive SHA-256: `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`
- Mode: independent read-only review of the frozen subject
- Report status: historical report only
- Verdict: `FAIL`

## Scope

The review traced the dated Rust channel manifest through the exact source
archive, source commit and selected members; registry locks, generated
manifests, checksums, legal-file inventories, and selected-root graph; SPDX
commit, tree, and blobs; LLVM and LLD license roots; the material and toolchain
ledgers; and the Noise, Cacophony, typenum-origin, rust-num-origin, and
Rust-PR-49000 origin records.

The review used no network, sibling repository, Amazon or internal input,
closed-engine input, or unbound language input. It made no repository edits.
All review commands targeted the frozen Git object or an extraction of its
archive. The later addition of this historical report is not part of the
reviewed subject.

## Identity And Candidate Commands

The following commands reproduced the frozen identity:

```text
git rev-parse \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386^{commit} \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386^{tree}

git archive --format=tar \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386 |
  shasum -a 256

git fsck --full --no-dangling
git diff --check \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386^ \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386
```

Results were the exact subject commit, tree, and archive SHA-256 above;
`git fsck` and `git diff --check` emitted no error.

The candidate and mutation suites executed were:

```text
tools/p13-noise-evidence --skip-runtime
tools/p13-noise-evidence
tools/test-p13-noise-evidence
tools/test-p13-source-fetch
tools/test-p13-rustc-driver
tools/validate-p13 --no-cargo --review-candidate
tools/p13-evidence
ruby -c tools/p13-noise-evidence.rb
ruby -c tools/p13-source-fetch.rb
ruby -c tools/p13-rustc-driver.rb
ruby -c tools/validate-p13.rb
```

They passed from the clean frozen checkout; the aggregate command returned
`P13_REVIEW_CANDIDATE_PASS`. The same full runtime command from a shared
`/private/tmp` archive extraction encountered the verifier's ancestor-ctime
guard after unrelated temporary-directory churn; the clean-checkout execution
passed and the environmental extraction result was not classified as a source
finding.

## Reproduced Source Chain

The local manifest and source archive reproduced:

```text
channel-rust-1.98.0.toml
bytes: 898637
sha256: 3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a

rustc-1.98.0-src.tar.xz
bytes: 244440040
sha256: 271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e
source commit: 88d9e12ae178fab0fb5cc050a94da85685d449ea
```

The manifest contained that source URL, SHA-256, and source commit. The selected
root graph reproduced 397 packages, 317 registry packages, and tuple digest
`400397c713e3937e4885a40d44342468d65ada48b5475c79c02c531053b38980`.
The conservative compiler/Clippy closure reproduced 535 registry packages.

Local object-only checks with `GIT_NO_LAZY_FETCH=1` reproduced:

```text
Noise commit: ecdf084ece2bf92b16b1201b6ae5c99d23fb4151
Noise tree:   7ae97cd53c41891afca8fd1c1fe6c74945845c16
noise.md:     874aec33e8ee8b431be2733a24b619e863687802

Cacophony commit: 18b7348c54fd61fcd0c220298883de0d09c8364d
Cacophony tree:   3352eabffc931f8b9192c34d7c76d9fb39da5ac0
vector blob:      b8a271ed1aba8b4a56bf429e559d7947827123b4
license blob:     cf1ab25da0349f84a3fdd40032f0ce99db813b8b

SPDX commit: 24b4ed8996b5f8d3f91e51961b46803e9e356814
SPDX tree:   b96913f1e33b03c3da8666514f67452c657e0a17
```

The SPDX Apache-2.0, LLVM-exception, BSD-4-Clause-UC, and curl blob identities
matched the ledger. LLVM and LLD `LICENSE.TXT` hashes reproduced as
`8d85c1057d742e597985c7d4e6320b015a9139385cff4cbae06ffc0ebe89afee`
and `f7891568956e34643eb6a0db1462db30820d40d7266e2a78063f2fe233ece5a0`;
both state Apache License 2.0 with LLVM exceptions.

## Coherent Provenance Substitution

Against the extracted frozen subject, the mutation loaded
`toolchain_source_closure` from `P13-NOISE-SOURCES.yaml` and
`selected_build_toolchain_candidate` from `TOOLCHAIN-PROVENANCE.yaml`, then
changed these duplicate provenance fields together:

```text
provider: Substituted_Project
source_url: https://example.invalid/substituted/rust
source_commit: 0123456789abcdef0123456789abcdef01234567
manifest_url: https://example.invalid/substituted/channel.toml
manifest_size: 1
manifest_sha256: 1111111111111111111111111111111111111111111111111111111111111111
manifest_verified.observed_size: 1
manifest_verified.observed_sha256: 1111111111111111111111111111111111111111111111111111111111111111
source_archive.local_path: /tmp/substituted-rust-src.tar.xz
```

The command invoked
`P13NoiseEvidence.validate_toolchain_source_provenance(record,
provenance: changed)`. A negative control changed the authoritative nested
`source_archive.sha256` instead. Exact output:

```text
BASELINE=true
DUPLICATE_PROVENANCE_SUBSTITUTION_ACCEPTED=true
AUTHORITATIVE_ARCHIVE_SUBSTITUTION_REJECTED=P13 Rust source provenance archive differs
```

The control proves the relation ran. The accepted substitution proves that the
provider, repository identity, top-level source commit, manifest identity and
verification, and duplicate archive path can contradict the source chain while
the P13 provenance relation succeeds.

## Legal-Inventory Counterexample

ADR-0028 requires a complete legal-file inventory for all 535 registry
packages in the conservative compiler/Clippy lock universe. The candidate's
`rust_registry_legal_file_path?` returned:

```text
THIRD_PARTY=false
THIRD_PARTY.txt=false
CREDITS.TXT=false
```

The exact source archive and package checksum metadata contain:

```text
vendor/capstone-0.14.0/THIRD_PARTY.txt
bytes: 1752
sha256: c4489e73a9f2ec47bbb76ea770480e77c4446cfb801ae6c739bca91ae4ff3656

vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT
bytes: 3144
sha256: b4baaceb3ad09b94b0925c5bab1238562f8fc202343141e1e0618db51d21a535
```

The first file contains Capstone's distinct BSD-style grant, copyright notice,
and redistribution conditions; the `capstone 0.14.0` root `LICENSE` is MIT.
The package is outside the selected 397-package graph, but ADR-0028 explicitly
requires complete inventory across the 535-package conservative universe.

Therefore the recorded 986-file inventory and its matching hashes in
`P13-NOISE-SOURCES.yaml`, `MATERIALS.yaml`, and
`TOOLCHAIN-PROVENANCE.yaml` are cross-ledger consistent but incomplete by
construction. The passing aggregate gate did not detect either omitted path.

## Findings

- P0: none.
- P1: duplicate immutable toolchain-provenance fields are not semantically
  bound to the authoritative channel-manifest and source-archive relation, so a
  coherent contradictory source identity is accepted.
- P2: the mandatory complete 535-package legal-file inventory omits at least
  one checksum-bound, obligation-bearing third-party license and one
  checksum-bound attribution file; all three ledgers pin the incomplete
  inventory.
- P3: none.

FAIL
