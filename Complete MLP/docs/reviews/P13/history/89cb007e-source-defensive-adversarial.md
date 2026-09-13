# P13 Source Defensive Adversarial Review

- Role: `source-defensive-adversarial`
- Review instance: `01a05585-18f3-7933-a1a2-8420bde7a7c5`
- Subject commit: `89cb007efc15a67b3f2c9af1af8973a7026538fa`
- Subject tree: `90ec37b2da562b037b4450ab4efdf5c9c124fea7`
- Archive SHA-256: `009aa16f2d1eafb7dc3b0a3348e21908e5bcd4dead32feb785da2fe6ac206b5b`
- Mode: independent read-only offline
- Verdict: `FAIL`

## Scope

Primary evidence was inspected without network access, repository edits,
sibling repositories, Amazon/internal material, closed-engine material, or
unprovenanced language. Review conclusions were not used as evidence.

The review attacked the six `USR-036` closures and also probed duplicate YAML,
semantic-hash binding, path-source reachability boundaries, and prohibited
product admission.

## Commands And Results

The exact commit, tree, and archive SHA-256 reproduced. `git status` and
`git diff --check` were clean. `tools/test-p13-noise-evidence` emitted
`P13_NOISE_EVIDENCE_TESTS_PASS`.

The exact Rust source archive reproduced 244,440,040 bytes and SHA-256
`271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e`.
The selected roots contained 9,720 files and approximately 124 MiB. A
targeted search found 27 bare `Based on`, `Based off of`, or `Based upon`
lines in 25 selected files.

Direct witness calls returned no relevant witness for sampled exact selected
files, including:

```text
compiler/rustc_codegen_cranelift/example/std_example.rs:143
compiler/rustc_codegen_cranelift/example/track-caller-attribute.rs:1
library/core/src/asserting.rs:4
library/alloctests/tests/sort/known_good_stable_sort.rs:5
```

FIFO and CC0 counterexamples failed closed. Duplicate and aliased YAML was
rejected. Intel and LoongArch hashes and dispositions matched. Runtime,
product-dependency, and packaging admission remained `NOT_GRANTED`.

## Counterexample

The matcher recognized `Implementation based on` but not a comment beginning
directly with `Based on`. Exact selected source therefore contained current
origin statements absent from the committed dispositions.

Both governance parsers also required exactly one space after a backticked
decision ID. A valid Markdown row with two spaces after `USR-037` was ignored;
if its traceability and manifest rows were also omitted, validation accepted
the omission. Conversely, a future exact row added to all three ledgers was
rejected by the fixed `USR-036` ceiling.

## Findings

P0: none.

P1: none.

P2:

- Bare current `Based on` statements across selected files were not bound to
  exact origin dispositions.
- Harmless Markdown whitespace could hide future decision rows, while a fixed
  current ceiling rejected future contiguous rows.

P3: none.

`FAIL`
