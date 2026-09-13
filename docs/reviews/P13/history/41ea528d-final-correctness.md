# P13 Historical Final Correctness Review

- Role: `correctness`
- Review instance: `01a050b7-1ffb-7702-8a40-e180bfcc1640`
- Review date: `2026-08-30`
- Subject commit: `41ea528df9b6163a9a08a297d21c9c8f8c18b386`
- Subject tree: `3b518a172867f587614c0947c63e83cc7111f75e`
- Archive SHA-256:
  `86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8`
- Mode: independent, read-only, offline final-correctness review
- Historical status: this report records the review of the immutable subject
  above and is not part of that subject
- Verdict: `FAIL`

## Scope

The review inspected the frozen P13 implementation and primary tests for:

- deny-first policy and one-time confirmation behavior;
- strict protocol v1 compatibility and protocol v2 completeness;
- the credential-free local Unix server and immutable snapshot boundary;
- session, confirmation, caller, timeout, and cancellation boundaries;
- Home Assistant and Wyoming compatibility evidence;
- Noise transport capability evidence; and
- the exact Rust source and legal-inventory correction.

Primary paths included:

- `crates/policy-engine/`
- `crates/protocol/`
- `crates/session-engine/`
- `crates/nlu-server/src/server.rs`
- `crates/nlu-server/src/runtime.rs`
- `crates/nlu-server/tests/runtime_contract.rs`
- `tools/validate-p13.rb`
- `tools/p13-noise-evidence.rb`
- `tools/test-validate-p13.rb`
- `tools/test-p13-noise-evidence.rb`
- `docs/adr/ADR-0019-policy-protocol-v2-and-local-server.md`
- `docs/adr/ADR-0028-exact-rust-toolchain-source-closure.md`
- `docs/evidence/P13-NOISE-SOURCES.yaml`
- `docs/evidence/TOOLCHAIN-PROVENANCE.yaml`
- `docs/clean-room/MATERIALS.yaml`

The review used no network, sibling repository, Amazon or internal material,
closed-engine input, or unprovenanced linguistic data. It made no repository
edit. The behavioral counterexample used only `FIXTURE_TECNICA` bytes in a
temporary test copy of the frozen subject.

## Subject Identity

Commands:

```sh
git show -s --format='commit=%H%ntree=%T' \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386
git rev-parse HEAD 'HEAD^{tree}'
git archive --format=tar \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386 |
  shasum -a 256
git status --short --branch --untracked-files=all
git diff --check \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386^ \
  41ea528df9b6163a9a08a297d21c9c8f8c18b386
```

Results:

```text
commit=41ea528df9b6163a9a08a297d21c9c8f8c18b386
tree=3b518a172867f587614c0947c63e83cc7111f75e
archive_sha256=86ae51e5c045d8d64c1d7dcbd08a3f628e11a2d258177e289cba7174fa56b8b8
status=## main
git_diff_check=PASS
```

## Baseline Commands

The frozen candidate's required gates passed:

```sh
tools/validate-p13 --no-cargo --review-candidate
tools/test-validate-p13
tools/p13-noise-evidence --skip-runtime
tools/test-p13-noise-evidence

env PATH="$PWD/.tools/rust-1.98.0/bin:/usr/bin:/bin" \
  RUSTC="$PWD/.tools/rust-1.98.0/bin/rustc" \
  .tools/rust-1.98.0/bin/cargo test -p nlu-server --lib

env PATH="$PWD/.tools/rust-1.98.0/bin:/usr/bin:/bin" \
  RUSTC="$PWD/.tools/rust-1.98.0/bin/rustc" \
  .tools/rust-1.98.0/bin/cargo test \
  -p nlu-server --test runtime_contract
```

Observed terminal results:

```text
P13_REVIEW_CANDIDATE_PASS
P13_GATE_TESTS_PASS
P13_NOISE_SOURCE_EVIDENCE_PASS
P13_NOISE_RUNTIME_SKIPPED
P13_NOISE_CAPABILITY_ONLY_PASS
P13_NOISE_EVIDENCE_TESTS_PASS
nlu-server library: 18 passed; 0 failed
nlu-server runtime_contract: 9 passed; 0 failed
```

Those passing tests did not cover cancellation of a request that had entered
the bounded queue but had not yet been admitted by a request worker.

## Counterexample 1: Timed-Out Queued Request Mutates State

At the frozen subject, `RequestJob` in
`crates/nlu-server/src/server.rs` carried only the snapshot, request bytes,
and response sender. It carried no deadline, cancellation token, or atomic
admission state. `execute_request_until` returned `RequestTimeout` when
`recv_timeout` expired, but `request_worker_loop` later invoked
`handler.handle` for every dequeued job without checking whether its caller
had already timed out.

This matters for the real runtime contract. `NluRuntime::dispatch_at` can
create a pending continuation, store or consume a one-time confirmation, or
cancel pending session and confirmation state. The snapshot is immutable as a
generation, but these bounded stores intentionally use interior mutation.

The read-only counterexample copied the frozen subject to a private temporary
directory and added a test-only handler and state:

1. Start one request worker with a queue capacity of two.
2. Submit `FIXTURE_TECNICA_BLOCKER`; its handler waits on a two-party barrier
   and occupies the only worker.
3. Submit `FIXTURE_TECNICA_MUTATE` with a 10 millisecond absolute deadline.
   Its handler changes an `AtomicBool` from `false` to `true`.
4. Wait for the caller to receive `ServerErrorCode::RequestTimeout`.
5. Confirm that the state is still `false`, then release the blocker.
6. Submit `FIXTURE_TECNICA_DRAIN`. FIFO completion proves that the worker has
   drained the expired mutation job.
7. Read the mutation state again.

The targeted test was run with the same pinned Rust 1.98.0 command used for
the baseline server tests. Its observations were:

```text
timeout_code=RequestTimeout
mutated_before_worker_release=false
blocker_response=FIXTURE_TECNICA_BLOCKER_DONE
drain_response=FIXTURE_TECNICA_DRAINED
mutated_after_worker_drain=true
```

The result is deterministic: the barrier proves that the mutating request was
queued when its caller timed out, and the drain request proves that the worker
later passed it through `handler.handle`. The existing slow-handler test only
proved that the socket closed promptly; it did not inspect late handler side
effects or pending runtime state.

Therefore a caller could observe timeout and retry or abandon a request while
the first request subsequently changed session or confirmation state. This
violated the bounded request-time contract and the fail-closed caller/session
boundary.

## Counterexample 2: Incomplete Legal Inventory

ADR-0028 required a complete legal and attribution inventory for all 535
registry packages in the conservative compiler/Clippy lock universe. The
subject's discovery predicate recognized conventional license, notice,
author, contributor, and license-directory names, but not these exact
nonstandard basenames:

```sh
/usr/bin/ruby --disable-gems -Itools -rp13-noise-evidence -e '
  paths = %w[
    THIRD_PARTY.txt
    capstone/CREDITS.TXT
    xz-5.2/PACKAGERS
    xz-5.2/THANKS
  ]
  paths.each do |path|
    puts "#{P13NoiseEvidence.rust_registry_legal_file_path?(path)}\t#{path}"
  end
'
```

Result:

```text
false	THIRD_PARTY.txt
false	capstone/CREDITS.TXT
false	xz-5.2/PACKAGERS
false	xz-5.2/THANKS
```

The provenance-bound source input was:

```text
path=/private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
bytes=244440040
sha256=271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e
archive_root=rustc-1.98.0-src
```

The archive identity and omitted members were reproduced with:

```sh
wc -c /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
shasum -a 256 /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
bsdtar -tf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz |
  grep -E '/(THIRD_PARTY\.txt|CREDITS\.TXT|PACKAGERS|THANKS)$'
bsdtar -xJOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/capstone-0.14.0/THIRD_PARTY.txt |
  shasum -a 256
bsdtar -xJOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT |
  shasum -a 256
bsdtar -xJOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/lzma-sys-0.1.20/xz-5.2/PACKAGERS |
  shasum -a 256
bsdtar -xJOf /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz \
  rustc-1.98.0-src/vendor/lzma-sys-0.1.20/xz-5.2/THANKS |
  shasum -a 256
```

Direct enumeration of the exact bound Rust 1.98.0 source archive, extraction
with `bsdtar -xJOf`, byte counts with `wc -c`, hashes with
`shasum -a 256`, and JSON parsing of each package's
`.cargo-checksum.json` reproduced four checksum-bound omitted files:

| Archive-relative path | Bytes | SHA-256 | Content |
| --- | ---: | --- | --- |
| `vendor/capstone-0.14.0/THIRD_PARTY.txt` | 1,752 | `c4489e73a9f2ec47bbb76ea770480e77c4446cfb801ae6c739bca91ae4ff3656` | Capstone BSD grant and redistribution conditions |
| `vendor/capstone-sys-0.18.0/capstone/CREDITS.TXT` | 3,144 | `b4baaceb3ad09b94b0925c5bab1238562f8fc202343141e1e0618db51d21a535` | Contributor attribution |
| `vendor/lzma-sys-0.1.20/xz-5.2/PACKAGERS` | 8,595 | `8ab0db1c1bf19383b6fd4e7f3fc1a627f7e4d44119fb019469644131df99c0e2` | Public-domain and GPLv2+ license guidance |
| `vendor/lzma-sys-0.1.20/xz-5.2/THANKS` | 2,673 | `bcb2f3d036e823232e43706850e07bf8a493c49798354c4c97b2f2b15bf64a68` | Contributor attribution |

All four hashes matched their package checksum metadata. None of the four
paths appeared in the subject's claimed 986-file legal inventory or its
reviewed legal-file dispositions.

The focused in-memory mutation inserted a correctly hashed
`THIRD_PARTY.txt` into fixture package checksum metadata, recomputed the
checksum inventory, and left the legal inventory unchanged. Direct validation
returned:

```text
predicate_THIRD_PARTY=false
checksum_contains_THIRD_PARTY=true
legal_inventory_contains_THIRD_PARTY=false
validator_accepted=true
```

The affected packages were outside the selected 397-package rustc/Clippy
graph and outside the sysroot lock, so this did not demonstrate execution of
an unapproved component. It did demonstrate that the mandatory conservative
source inventory was incomplete and that the passing evidence gate could not
detect the omission.

## Findings

P0: none.

P1: none.

P2:

- A request can return `RequestTimeout` while queued and later enter the
  mutable runtime handler, changing pending session or confirmation state
  after the caller has observed failure.
- The claimed complete compiler/Clippy legal inventory omits four
  checksum-bound license or attribution files because the shared discovery
  predicate does not recognize their basenames.

P3: none.

Both P2 findings were open on the frozen subject. The candidate therefore did
not satisfy the P13 completion rule requiring no open P0 through P2 finding.

FAIL
