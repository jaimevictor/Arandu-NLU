# P14 Final Test-Oracle Review

- Role: `test-oracle`
- Review instance: `01a0879a-2e3c-78e3-8dd7-325aa6b4fcad`
- Subject commit: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Comparison tree: `2a2d6a8bd8e519388f2f2f86b6009097324343df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

## Scope And Commands

The reviewer mutation-tested regressions for every USR-042 blocker class and
the P14 evidence parser. The exact P14 gate passed 132 companion tests, 8
metadata tests, 23 Noise packages, 218 Rust tests with 3 ignores, and 38
Clippy targets.

Evidence mutations for skipped, duplicate, vacuous, renamed, missing,
forged-count, and ambiguous tests were rejected. Wrong commit/tree, dirty
subject, Noise checksum, and Git-mode mutations were also rejected.
Reconciliation, reauthentication, stop, typed TTL, node/session tombstone,
and no-conversation routing mutations failed as intended.

## Counterexamples

- Moving endpoint cleanup before process wait left all helper-process tests
  green because the fake marks the process exited inside `terminate()`. A
  delayed-exit fake detected the mutation.
- Disabling expiry of shared `_expired_operations` left all execution and
  ledger tests green. A capacity-two, three-cohort probe then produced
  `new,new,new,new,capacity,capacity` instead of six `new` results.

## Findings

- P0: none.
- P1: The helper child-exit ordering regression is not detected by the
  committed fake and oracle.
- P2: Shared operation tombstone rotation lacks a multi-cohort regression.
- P3: none.

`FAIL`
