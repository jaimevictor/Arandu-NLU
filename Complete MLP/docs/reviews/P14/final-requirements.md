# P14 Final Requirements Review

- Role: `requirements`
- Review instance: `01a08799-f928-7363-8d3b-0b7a05bf04e1`
- Subject commit: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Comparison tree: `2a2d6a8bd8e519388f2f2f86b6009097324343df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

## Scope And Commands

The reviewer derived the terminal scope from `AGENTS.md`, `USR-042`,
ADR-0042, accepted transfers, the requirement matrix, source, tests, and
validators. It verified the exact commit, tree, parent, clean state, and 20
allowlisted changed paths. No P13, linguistic, dependency, source-selection,
or optional-feature change was present. Artifact production and both
architectures remained disabled.

The exact P14 gate passed 132 companion tests, 8 metadata tests, 23 Noise
packages, 218 Rust tests with 3 ignores, and 38 Clippy targets. Wrong-tree and
companion-identity substitutions were rejected. A focused 13-test
ledger/close suite passed despite the counterexamples.

## Counterexamples

- If retirement could not persist the restart marker, the fallback changed
  only process memory. Reconstructing state from the still-false persisted
  value then allowed a fresh effect to dispatch without reconciliation.
- Production derives a stable operation identity but always emits
  `DeliveryKind::Initial`. After the active entry and tombstone expired, the
  same production-shaped identity completed again and produced a third
  service call instead of being rejected.

## Findings

- P0: none.
- P1: Restart-reconciliation fallback is not durable across process
  reconstruction, violating `P14-HA-034` and ADR-0042.
- P2: Expired production operation identities become new work, violating
  `P14-HA-032`.
- P3: none.

The terminal correction therefore does not close duplicate-effect and
bounded-operation-history requirements. Stop revocation, Noise Git modes,
typed-session TTL, helper post-proof cleanup, exact test/subject binding, and
continuation without a conversation ID were otherwise covered.

`FAIL`
