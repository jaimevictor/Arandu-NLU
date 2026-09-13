# P13 Historical Defensive Adversarial Source Review

- Role: `source-defensive-adversarial`
- Review instance: `01a050b7-18ea-7bb3-8b9a-c7df5dfb75ca`
- Subject commit: `41ea528df9b6163a9a08a297d21c9c8f8c18b386`
- Subject tree: `3b518a172867f587614c0947c63e83cc7111f75e`
- Archive SHA-256: `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`
- Mode: independent read-only, offline primary-evidence inspection
- Verdict: `FAIL`

## Scope

The reviewer inspected the immutable subject, the exact local Rust 1.98.0
source archive and channel manifest, the pinned SPDX Git objects, the P13
source ledgers, `tools/p13-noise-evidence.rb`, its mutation suites, the direct
Rust driver guard, and the acquisition extractor. The review used no network,
sibling repository, Amazon or internal material, unbound language data, or
prior review conclusion. It made no repository edits and began and ended with
the worktree clean at the subject.

The adversarial scope covered coherent checksum, count, byte-total, and
inventory-digest changes; nested non-OSI legal text; dependency-edge and root
reachability changes; LLVM and SPDX field changes; path components and casing;
stale counts; duplicate YAML; symlinks and archive traversal; and source
substitution across validation command windows.

## Subject Identity

Commands and results:

```text
git show -s --format='commit=%H%ntree=%T' 41ea528df9b6163a9a08a297d21c9c8f8c18b386
commit=41ea528df9b6163a9a08a297d21c9c8f8c18b386
tree=3b518a172867f587614c0947c63e83cc7111f75e

git rev-parse HEAD HEAD^{tree}
41ea528df9b6163a9a08a297d21c9c8f8c18b386
3b518a172867f587614c0947c63e83cc7111f75e

git archive --format=tar 41ea528df9b6163a9a08a297d21c9c8f8c18b386 | shasum -a 256
86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8  -
```

`git status --short --branch --untracked-files=all` returned only `## main`.

## Mandatory Gates

These commands passed:

```text
tools/p13-noise-evidence --skip-runtime
tools/p13-noise-evidence
tools/validate-p13 --no-cargo --review-candidate
tools/test-p13-noise-evidence
tools/test-p13-rustc-driver
tools/test-p13-source-fetch
tools/test-p13-evidence
tools/test-validate-p13
/usr/bin/ruby -c tools/p13-source-fetch.rb
/usr/bin/ruby -c tools/p13-rustc-driver.rb
/usr/bin/ruby -c tools/p13-noise-evidence.rb
/usr/bin/ruby -c tools/test-p13-noise-evidence.rb
git diff --check 41ea528df9b6163a9a08a297d21c9c8f8c18b386^ 41ea528df9b6163a9a08a297d21c9c8f8c18b386
```

The source manifest and archive independently reproduced 898637 bytes with
SHA-256 `3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a`
and 244440040 bytes with SHA-256
`271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e`.
The pinned SPDX commit and tree reproduced exactly, and both
`BSD-4-Clause-UC` and `curl` reported `isOsiApproved="false"`.

A coherent dependency-edge mutation that made `curl-sys` reachable, while
also updating the active graph count and digest, failed with
`P13 Rust reviewed inactive package reached active graph`. Mixed-case
`CuRl/LiCeNsEs/BUSL-1.1.txt` was discovered, duplicate YAML was rejected, and
the source-fetch suite rejected symlinks, traversal, links, collisions,
unsupported entry types, malformed tar, and archive identity changes.

## Counterexample 1: Coherent BUSL Addition

The reviewer loaded the real 535-package compiler and Clippy registry universe
from the exact source archive, added
`nested/LICENSE-BUSL-1.1.txt` to the extracted
`vendor/addr2line-0.24.2` fixture, updated its `.cargo-checksum.json`, and
recomputed the complete checksum inventory, legal-file count, legal byte
total, and legal inventory digest before calling
`P13NoiseEvidence.validate_rust_registry_licenses`.

Observed result:

```text
COUNTEREXAMPLE_PACKAGE=vendor/addr2line-0.24.2
COUNTEREXAMPLE_PATH=nested/LICENSE-BUSL-1.1.txt
LEGAL_COUNT=986->987
LEGACY_RECORDED_COUNT=981
CHECKSUM_COUNT_BYTES_AND_DIGESTS_RECOMPUTED=true
PRODUCTION_VALIDATOR_ACCEPTED=true
```

`tools/p13-noise-evidence.rb` derives `legacy_legal_paths` from basenames that
match the old prefix predicate and excludes those rows from
`reviewed_legal_delta_rows`. It then checks only that the ledger field
`legacy_legal_file_count` still equals literal `981`; it never compares that
field with the derived legacy rows. The committed BUSL regression uses
`LICENSES/BUSL-1.1.txt`, which enters the new delta set, and therefore does not
cover a nested basename that begins with `LICENSE`.

This is a false acceptance of coherently updated non-OSI source evidence and
violates ADR-0028 and the repository OSI-only source boundary.

## Counterexample 2: Archive Substitution Window

The verifier hashes `/private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz`
once in `verify_large_file`, releases that operation, and later supplies the
path independently to multiple `bsdtar` processes. It retains no verified file
descriptor or inode identity and performs no hash or identity check after any
extraction.

Primary filesystem inspection showed:

```text
/private/tmp/p13-rust-source mode=drwxr-xr-x uid=503
/private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz mode=-rw-r--r-- uid=503
```

The read-only counterexample schedule is:

1. Present the official archive while `verify_large_file` checks its size and
   SHA-256.
2. After that function returns, replace the owner-writable path with a crafted
   archive.
3. Preserve the exact allowlisted manifests, locks, generated Cargo manifests,
   checksum documents, and inventoried legal files, but alter or add source
   members that the verifier never extracts.
4. Let each later `bsdtar -xJf ARCHIVE_PATH` invocation consume the substitute.

The extracted allowlist and its digests still match while the outer official
archive identity no longer applies to the source being classified. The
reviewer did not mutate the actual archive because the review was strictly
read-only; the one-time verification and later unguarded path opens establish
the substitution window directly.

This permits false source and license closure under a same-UID substitution
and violates the fail-closed provenance boundary.

## Findings

P0: none.

P1:

- Coherent nested `LICENSE-BUSL-1.1.txt` additions can bypass the reviewed legal
  delta because the recorded legacy count is not derived or authenticated.
- The exact Rust source archive is not identity-bound across its extraction
  command windows, permitting verified-path substitution before source use.

P2: none.

P3: none.

FAIL
