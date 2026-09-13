# P13 Historical Source-Discovery Review

- Role: `source-discovery`
- Review date: `2026-08-31`
- Subject commit: `edf6e2c888c841c423f42a19c110072f3b6f7ec7`
- Subject tree: `b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652`
- Archive SHA-256: `1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa`
- Mode: independent retrospective, read-only, and offline
- Verdict: `FAIL`

## Scope

Only the frozen subject's Git objects and its hash-matched local Rust source
archive were inspected. The review did not use current-worktree conclusions,
prior-review conclusions, a sibling repository, Amazon/internal material,
Sophia or another closed engine, network access, or linguistic data. The
report is retrospective evidence and is not a review of a replacement.

The review concentrated on the source-discovery contract in
`tools/p13-noise-evidence.rb`, the exact inventories in
`docs/evidence/P13-NOISE-SOURCES.yaml`, and the selected Rust path-source bytes.

## Commands And Results

- `git rev-parse 'edf6e2c888c841c423f42a19c110072f3b6f7ec7^{tree}'`
  returned `b71a4ba735aaaea6e12a349d0e55c8f9c8a3d652`.
- `git archive --format=tar edf6e2c888c841c423f42a19c110072f3b6f7ec7 |
  shasum -a 256` returned
  `1d0de0722ef7fb838c2c86029746e0027e7f5dc4a105be3558df30f266771afa`.
- `git show
  edf6e2c888c841c423f42a19c110072f3b6f7ec7:tools/p13-noise-evidence.rb
  | ruby --disable-gems -c` returned `Syntax OK`.
- `git diff --check edf6e2c888c841c423f42a19c110072f3b6f7ec7^
  edf6e2c888c841c423f42a19c110072f3b6f7ec7 --` returned success.
- `stat -f 'archive_bytes=%z' /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz`
  returned `archive_bytes=244440040`; `shasum -a 256` returned the frozen
  evidence value
  `271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e`.
- `/usr/bin/tar -xJOf
  /private/tmp/p13-rust-source/rustc-1.98.0-src.tar.xz
  rustc-1.98.0-src/compiler/rustc_codegen_cranelift/src/debuginfo/emit.rs |
  nl -ba | sed -n '186,193p'` returned, at line 190,
  `// Address::Constant arm copied from gimli`.
- `git grep -n -F
  'compiler/rustc_codegen_cranelift/src/debuginfo/emit.rs'
  edf6e2c888c841c423f42a19c110072f3b6f7ec7 --
  docs/evidence/P13-NOISE-SOURCES.yaml` returned no match.

An offline Ruby harness evaluated the exact frozen
`tools/p13-rustc-driver.rb`, `tools/p13-source-fetch.rb`, and
`tools/p13-noise-evidence.rb` blobs obtained with `git show`, then invoked
`rust_registry_content_witness_rows` with the stated byte strings. It returned:

```text
origin-alone=[[1, "ORIGIN_DERIVED_OR_COPIED"]]
origin-plus-later-technical=[]
technical-alone=[]
wrapped-derived-at-byte-zero=[[1, "ORIGIN_DERIVED_OR_COPIED"]]
wrapped-derived-after-prelude=[]
wrapped-adapted-after-prelude=[]
archive-member=8636:2ba6e45e97cc8a963d0311dd487736d56c8069070a2f66d3661ff9e2d0547e33
archive-line-190=            // Address::Constant arm copied from gimli
archive-origin-rows=[]
```

The exact fixture bytes were:

```text
origin-alone:
// Copied from OpenBSD.

origin-plus-later-technical:
// Copied from OpenBSD.
/// pointer derived from it. Use as_mut_ptr to mutate it.

wrapped-derived-after-prelude:
FIXTURE_TECNICA_PRELUDE
// Derived
// from OpenBSD.

wrapped-adapted-after-prelude:
FIXTURE_TECNICA_PRELUDE
//! Adapted from
//! [styled_buffer]
```

The same frozen harness replaced only the
`ORIGIN_BASED_OR_INSPIRED` rejection regex's `IGNORECASE` option while
preserving its source. The control input was
`// Based on whether the queue is empty.\n`. Results:

```text
before-options=1 before-rows=[] before-digest=36a731c8a33eb520a9297697c15a5df1a05c8f4e8d244e68813c40da903a1f13
after-options=0 after-rows=[[1, "ORIGIN_BASED_OR_INSPIRED"]] after-digest=36a731c8a33eb520a9297697c15a5df1a05c8f4e8d244e68813c40da903a1f13
semantics-changed=true digest-changed=false
```

## Counterexample

The scanner detects `// Copied from OpenBSD.` by itself, and correctly emits
no witness for `pointer derived from it` by itself. Appending that unrelated
technical line to the genuine origin statement makes the genuine witness
disappear. This disproves statement-local rejection: the 1,024-byte,
up-to-16-line window at `tools/p13-noise-evidence.rb:3736-3750` allows later
prose to reject an earlier match.

The byte-zero wrapped `Derived` control is detected, but adding an unrelated
prelude makes the same statement disappear. This isolates the `\A` anchor in
the generic branch at `tools/p13-noise-evidence.rb:594`, rather than the
wrapped syntax, as the cause.

## Findings

P0: none.

P1: none.

P2:

1. Origin discovery is incomplete. The generic derived/copied branch at
   `tools/p13-noise-evidence.rb:594` is anchored to byte zero, while the
   non-first-line special branches cover only selected `Copied` forms.
   Consequently, non-first-line wrapped `Derived` and `Adapted` statements
   are omitted. The target grammar at `tools/p13-noise-evidence.rb:430-446`
   also omits the concrete lowercase named origin `gimli`. The exact selected
   archive therefore contains an undiscovered origin at
   `compiler/rustc_codegen_cranelift/src/debuginfo/emit.rs:190`.
   `docs/evidence/P13-NOISE-SOURCES.yaml:22967-22970` records only 115
   witnesses in 96 compiler/Clippy files and has no disposition for that
   file, despite the all-`compiler` selection at lines 22936-22940.

2. Rejection is not scoped to the matched statement. The implementation at
   `tools/p13-noise-evidence.rb:3736-3750` normalizes as many as 1,024 later
   bytes and 16 lines before applying a rejection regex. The reproduced
   counterexample shows unrelated later technical prose suppressing a genuine
   earlier origin witness, making the hash-bound inventory incomplete.

3. The discovery vocabulary digest does not bind rejection-regex options.
   `tools/p13-noise-evidence.rb:3618-3627` includes each primary regex's
   source and options but includes only each rejection regex's source. The
   reproduced option mutation changed scanner semantics while preserving the
   recorded vocabulary SHA-256 exactly. The evidence can therefore accept
   materially different discovery behavior under the same semantic identity.

P3: none.

`FAIL`
