# P14 Resumed Review Blocker Summary

- Subject commit: `7c22c9e3dad3b4cfc0d44a02553ff9cb93c0f2e7`
- Subject tree: `f4e1e6bb1a6222391aad0f670de30d81d871adcf`
- Review roles: `6`
- Verdicts: `6 FAIL`
- Gate transcript SHA-256:
  `857048940fa71275531405a88e2591c77b3c5704a0ff369e22f245846e96d743`

| ID | Severity | Consolidated blocker |
| --- | --- | --- |
| `P14-R4-01` | P0 | The reconciliation snapshot omits disabled, unexposed, or temporarily service-unavailable supported effect targets, so changed live effect state can retain the same digest and clear an unknown-effect barrier. |
| `P14-R4-02` | P0 | Live effect state can change after proof comparison while the durable barrier is being cleared; the stale proof still permits the durable and local barriers to become false. |
| `P14-R4-03` | P1 | `PairingBroker.claim` removes broker ownership, so an unexpected helper exit cannot revoke the claimed lifecycle epoch and the old epoch remains usable. |
| `P14-R4-04` | P1 | Home Assistant stop during paused platform forwarding closes and removes the runtime, but resumed setup returns true and leaves `entry.runtime_data` referencing the closed runtime. |
| `P14-R4-05` | P2 | Runtime-construction failure can discard a safety state without releasing its process-local restart-journal owner claim, retaining stale owners and preventing exact durable clearing. |
| `P14-R4-06` | P2 | The committed suite does not kill proof replay or removal of endpoint and peer binding checks. |
| `P14-R4-07` | P2 | The exact gate accepts and re-emits optional host warnings and unrelated metadata diagnostics, permitting multiple accepted PASS transcript byte streams. |

No P3 finding was reported. The exact role reports are
`resumed-requirements.md`, `resumed-correctness.md`,
`resumed-test-oracle.md`, `resumed-risk.md`,
`resumed-reproducibility.md`, and `resumed-runtime-adversarial.md`.

Under the 2026-09-11 amendment to ADR-0049, the next candidate is limited to
these seven IDs, their direct regressions, affected validator closure, and
necessary evidence. It adds no optional feature or weakened requirement.
