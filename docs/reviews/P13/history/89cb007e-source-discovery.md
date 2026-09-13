# P13 Source-Discovery Review

- Role: `source-discovery`
- Review instance: `01a05584-f25b-7493-b27d-08e27a51bdc2`
- Review date: `2026-08-30`
- Subject commit: `89cb007efc15a67b3f2c9af1af8973a7026538fa`
- Subject tree: `90ec37b2da562b037b4450ab4efdf5c9c124fea7`
- Archive SHA-256: `009aa16f2d1eafb7dc3b0a3348e21908e5bcd4dead32feb785da2fe6ac206b5b`
- Mode: independent read-only offline
- Verdict: `FAIL`

## Scope

Inspected primary evidence and pinned local sources at the exact subject. No
network, sibling repository, Amazon/internal material, closed engine,
unprovenanced language data, or prior-review conclusions were used. No
repository file was modified.

## Commands And Results

- `git show -s --format='%H %T' HEAD` matched the required commit and tree.
- `git archive --format=tar <commit> | shasum -a 256` matched the required
  archive SHA-256.
- Final `git status --short --untracked-files=all`, `git diff --check`, and
  changed-scope checks were clean. No changes occurred under `crates`,
  `schemas`, `data`, or `tools/p13-noise-probe`.
- `tools/test-p13-source-fetch.rb` emitted
  `P13_SOURCE_FETCH_TESTS_PASS`.
- `tools/test-validate-p13` emitted `P13_GATE_TESTS_PASS`.
- `tools/p13-noise-evidence --skip-runtime` emitted every expected source,
  projection, advisory, runtime-skipped, and capability marker.
- `ruby --disable-gems tools/test-p13-noise-evidence.rb` emitted
  `P13_NOISE_EVIDENCE_TESTS_PASS`.

Independent archive walks matched 23 selected Noise packages, 194 projected
text files, the exact Noise and removed-Cacophony Git identities, the
244,440,040-byte Rust source archive, 18 selected Rust members, and all four
Rust inventories. The Intel rejection, LoongArch GPL/GCC-exception bindings,
and 36-row governance ledgers also matched.

## Counterexample

The active record at `docs/evidence/P13-NOISE-SOURCES.yaml:13612` had both
`NONSTANDARD_CC0` and `ORIGIN_TRANSLATED_OR_PORTED`. Its path, bytes, hash,
witnesses, and active reachability were retained while its non-OSI tuple was
replaced by the globally valid generic-origin tuple.
`validate_rust_registry_content_dispositions` returned success:

```text
ACTIVE_MIXED_COUNTEREXAMPLE_ACCEPTED
```

## Findings

P0: none.

P1: none.

P2: Mixed-witness disposition precedence was not enforced. A generic origin
tuple could override a `NONSTANDARD_*` or `RESTRICTIVE_*` witness. Required
precedence was
`RESTRICTIVE/NONSTANDARD > ORIGIN > ALTERNATIVE > PERMISSIVE`.

P3: none.

`FAIL`
