# P13 Source Acquisition And Replay

- Phase: `P13`
- Transfer runtime: `/usr/bin/ruby` 2.6.10p210
- Git executable: `/Library/Developer/CommandLineTools/usr/bin/git` 2.50.1
- Crate URL template:
  `https://static.crates.io/crates/{name}/{name}-{version}.crate`
- Fetcher allowed HTTPS hosts: `static.crates.io`, `static.rust-lang.org`,
  `creativecommons.org`
- Redirect policy: reject
- Existing-file policy: accept only the exact recorded size and SHA-256
- Result: `VERSIONED_ACQUISITION_AND_OFFLINE_REPLAY_RECIPE_BOUND`

This recipe acquires only hash-pinned technical source evidence. It is not a
product build or runtime network entitlement. Acquisition writes only to
`/private/tmp` or ignored `data/quarantine`; no acquired bytes enter the Git
lineage. Validation and the capability probe remain offline.

## Rust Toolchain Source

Acquire the dated channel manifest and the exact full source archive it names:

```text
tools/p13-source-fetch \
  https://static.rust-lang.org/dist/2026-08-20/channel-rust-1.98.0.toml \
  898637 \
  3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a \
  /private/tmp/p13-rust-source/channel-rust-1.98.0.toml

tools/p13-source-fetch \
  https://static.rust-lang.org/dist/2026-08-20/rustc-1.98.0-src.tar.xz \
  244440040 \
  271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e \
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
```

The manifest binds source commit
`88d9e12ae178fab0fb5cc050a94da85685d449ea`. Offline validation first uses
the already-admitted `/usr/bin/tar` to list selected members through the held,
hash-verified archive descriptor. Type, path, depth, count, per-file size, and
aggregate-byte limits are checked before extraction. Validation then extracts
the exact source manifests, lockfiles, license roots, checksum-bound registry
files, and selected compiler, Clippy, and sysroot path-source files recorded
in `P13-NOISE-SOURCES.yaml`. Every extracted file is checked again. The
selected compiler/Clippy closure resolves 535 registry packages from `vendor`;
the sysroot resolves 30 registry packages from the separate `library/vendor`
root.

The verifier proves that the sole CC0-only package in the complete Rust notice
is `notify 8.2.0`, that its exact tuple occurs only in the excluded
rust-analyzer lock, and that `notify` is absent from the selected locks and
installed paths. The installed `rust-analyzer-proc-macro-srv` helper is bound
by exact bytes but is not selected or executed. Neither `notify` nor
rust-analyzer source is admitted.

The selected compiler, Clippy, and sysroot path-source scan also retains one
Intel `cpuid.def` member only as rejected audit evidence; its unidentified
restrictive terms are not licensed or admitted, and P14 must prove it
unreachable from both native builds. Two exact LoongArch headers are retained
under `GPL-3.0-or-later WITH GCC-exception-3.1`, bound to their header hashes,
both Rust-archive legal texts, and the exact SPDX license and exception
records. A Rust `\u{cc0}` source escape is not CC0 license evidence.

## Crate Archives

For each of the 23 records under `closure.packages` in
`P13-NOISE-SOURCES.yaml`, substitute the exact `name` and `version` in the URL
template and run:

```text
tools/p13-source-fetch \
  EXACT_HTTPS_URL \
  EXACT_archive_bytes \
  EXACT_archive_sha256 \
  /private/tmp/p13-snow-cargo-home/registry/cache/index.crates.io-1949cf8c6b5b557f/NAME-VERSION.crate
```

The fetcher rejects unlisted hosts, redirects, partial bytes, size differences,
hash differences, symlink destinations, and replacement of any existing file.
Creation uses a descriptor-relative atomic exclusive rename after complete
verification and final name-to-descriptor rebinding. The 23 output names,
sizes, and hashes come only from the frozen ledger.

For each fetched archive, replay the exact Cargo extraction with:

```text
tools/p13-source-fetch extract-crate \
  /private/tmp/p13-snow-cargo-home/registry/cache/index.crates.io-1949cf8c6b5b557f/NAME-VERSION.crate \
  EXACT_archive_bytes \
  EXACT_archive_sha256 \
  NAME-VERSION \
  /private/tmp/p13-snow-cargo-home/registry/src/index.crates.io-1949cf8c6b5b557f/NAME-VERSION
```

Extraction rejects unsafe or colliding paths, links, unsupported entry types,
insecure modes, malformed headers, payload or padding differences, an
archive-supplied `.cargo-ok`, and replacement of any existing destination.
Publication uses an owner-private staging tree and a descriptor-relative
atomic exclusive no-clobber directory rename through the held parent
directory. The replay adds Cargo's exact mode-`0644` `.cargo-ok` marker
containing `{"v":1}` and compares every output path, type, mode, and byte
against the archive-derived manifest.

## Immutable Git Sources

For each tuple below, create a new empty destination, fetch the exact commit,
and verify the commit and tree before reading any path:

```text
/Library/Developer/CommandLineTools/usr/bin/git init DESTINATION
/Library/Developer/CommandLineTools/usr/bin/git -C DESTINATION remote add origin REPOSITORY
GIT_TERMINAL_PROMPT=0 /Library/Developer/CommandLineTools/usr/bin/git \
  -C DESTINATION fetch --no-tags origin COMMIT
GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 \
  /Library/Developer/CommandLineTools/usr/bin/git \
  -C DESTINATION rev-parse COMMIT^{commit} COMMIT^{tree}
GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 \
  /Library/Developer/CommandLineTools/usr/bin/git \
  -C DESTINATION fsck --full --no-dangling
```

Exact tuples:

| Purpose | Repository | Commit | Destination |
| --- | --- | --- | --- |
| Noise revision 34 | `https://github.com/noiseprotocol/noise_spec` | `ecdf084ece2bf92b16b1201b6ae5c99d23fb4151` | `/private/tmp/p13-noise-spec-origin` |
| typenum copied-source binding | `https://github.com/paholg/typenum` | `67584b536d97c5503fa0f8d6ea1162eb4d9b8383` | `/private/tmp/p13-typenum-origin` |
| rust-num origin | `https://github.com/rust-num/num` | `4bbc34b083c72290781d68649dfbeb6629fa8e54` | `/private/tmp/p13-num-origin-full` |
| Rust PR 49000 origin | `https://github.com/cuviper/rust` | `032f93bd83b97b3480864e472ada1f5a34bfe806` | `/private/tmp/p13-rust-pr49000-origin` |
| pulldown-cmark copied file | `https://github.com/pulldown-cmark/pulldown-cmark.git` | `c05f017b899e85392af1a25e13bc7b5ca41cb063` | `data/quarantine/pulldown-cmark-upstream` |
| Redwood copied-source origin | `https://github.com/BenjaminRi/Redwood-Wiki.git` | `dfa58152b41d7eb5bcdd7563e30e5373692f8a3b` | `data/quarantine/redwood-wiki-upstream` |
| Hyperium HTTP copied-source origin | `https://github.com/hyperium/http.git` | `ab2ca71ead2a07e861a30637dc3fe1c300701a4e` | `data/quarantine/hyperium-http-upstream` |
| RustSec snapshot | `https://github.com/RustSec/advisory-db` | `6420e39260b3d771b049954cf5d52b57e2118da4` | `/private/tmp/nlu-rustsec-advisory-db` |
| removed Cacophony vector | `https://github.com/haskell-cryptography/cacophony` | `18b7348c54fd61fcd0c220298883de0d09c8364d` | `/private/tmp/p13-cacophony-origin` |
| SPDX license approval metadata | `https://github.com/spdx/license-list-XML` | `24b4ed8996b5f8d3f91e51961b46803e9e356814` | `/private/tmp/p13-spdx-license-list-XML` |

Use `git ls-tree` and `git show` only with
`GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0`. Exact trees, paths, blobs, byte
counts, and SHA-256 values are in `P13-NOISE-SOURCES.yaml` and
`MATERIALS.yaml`. Produce `/private/tmp/p13-noise-spec-rev34.md` only from
`ecdf084e:noise.md`, then verify its recorded 136,496 bytes and SHA-256.

The Redwood author's public permission is retained from an unauthenticated
request to
`https://github.com/pulldown-cmark/pulldown-cmark/issues/507?timeline_page=1`
at `2026-08-30T19:46:38Z`. The hash-pinned response is stored at
`data/quarantine/pulldown-cmark-issue-507-timeline-1.html`: 284,687 bytes,
SHA-256
`d4e75acafc782eb43a746ca6b519bc7eb32126361f745002283bbb476aea27fb`.
The upstream page may change; only those exact retained bytes are evidence.
Offline validation parses comment database ID `1596190824`, binds its author,
timestamp, body hash, exact Redwood commit and path, and the granted use,
modification, redistribution, and relicensing actions.

## Standalone Legal Code

Acquire the exact Creative Commons legal code with:

```text
tools/p13-source-fetch \
  https://creativecommons.org/licenses/by/4.0/legalcode.txt \
  18657 \
  9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411 \
  /private/tmp/p13-cc-by-4.0-legalcode.txt
```

## Offline Replay

After acquisition, disconnect network access and run:

```text
tools/p13-noise-evidence --skip-runtime
tools/p13-noise-evidence
tools/test-p13-noise-evidence
tools/test-p13-source-fetch
```

The verifier reads only the exact local paths above, validates every immutable
identity before use, executes no Cargo process, and prohibits Git lazy fetch.
A clean replay is successful only when it reconstructs the exact source
projection, private materialization, frozen package-graph evidence, direct
host capability artifacts, tests, and strict Clippy result.
