# P13 Source Quality And Security Review

- Role: `source-quality-security`
- Review instance: `b9bdf64e-25c4-58a9-a6ad-17436949678c`
- Review date: `2026-08-30`
- Subject commit: `89cb007efc15a67b3f2c9af1af8973a7026538fa`
- Subject tree: `90ec37b2da562b037b4450ab4efdf5c9c124fea7`
- Archive SHA-256: `009aa16f2d1eafb7dc3b0a3348e21908e5bcd4dead32feb785da2fe6ac206b5b`
- Mode: independent read-only
- Verdict: `FAIL`

## Scope

Primary code, tests, ADR-0033, source-acquisition evidence, material records,
and exact source members were inspected offline. The review covered
nonblocking/no-follow file handling, descriptor identity, archive bounds,
witness discovery, CC0 precision, special-rights dispositions, deterministic
hashes, and mutation resistance.

No network, sibling repository, Amazon/internal material, closed-engine
material, or unprovenanced language was used. The repository remained
unchanged.

## Commands And Results

- `git rev-parse HEAD HEAD^{tree}` matched the subject identities.
- `git archive --format=tar SUBJECT | shasum -a 256` matched the supplied
  archive hash; size was 36,577,280 bytes.
- The Rust source archive was 244,440,040 bytes with SHA-256
  `271fa73d8174f53d713c46a8310da7bf7cfdcfb8b7cfd1c2b74b84a83ae9fb1e`.
- Intel CPUID, both LoongArch headers, GPLv3, and GCC-exception member hashes
  matched their evidence records.
- `tools/test-p13-noise-evidence` emitted
  `P13_NOISE_EVIDENCE_TESTS_PASS`.
- `tools/test-p13-source-fetch` emitted `P13_SOURCE_FETCH_TESTS_PASS`.
- `tools/test-p13-rustc-driver` emitted `P13_RUSTC_DRIVER_TESTS_PASS`.
- `git diff --check SUBJECT^ SUBJECT` passed; final worktree status was clean.

## Counterexample

FIFO, symlink, hard-link, path substitution, Unicode escape, literal CC0,
special-disposition mutation, and hash-order counterexamples failed closed as
intended.

The origin matrix reproduced two omissions:

```text
same-line                 ORIGIN_BASED_OR_INSPIRED
wrapped-prefix            no witness
second-line-bare-copy     no witness
second-line-ported        ORIGIN_TRANSLATED_OR_PORTED
```

Static inspection also found that `max_archive_listing_bytes` was checked only
after `Open3.capture3` had buffered the complete untrusted listing.

## Findings

P0: none.

P1: none.

P2:

- Wrapped comment-prefix origin statements and non-first-line bare
  `Copied from` statements evaded witness generation.
- Archive-listing output was buffered without a limit before the 8 MiB
  post-capture check, allowing memory exhaustion before rejection.

P3: none.

`FAIL`
