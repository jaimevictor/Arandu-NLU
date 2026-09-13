# P14 USR-047 Replacement Review Blocker Summary

- Subject commit: `ba739823ffa7d55abc9042a62f4d5241108d1c49`
- Subject tree: `50a695d7cd0d81522d8d468fb0446fb857fee5df`
- Authorization base: `ea29e05368636a2c703b223b26828482dca4b1e9`
- Immediate parent: `386819483852f0c910243cad07ae90084fdd6f18`
- Review roles: `6`
- Verdicts: `5 FAIL`, `1 PASS`
- Gate transcript SHA-256:
  `bf53eb0e10e4054d069913022050bf74efa353fa0b5c3cd51180dec3279d57e4`
- Governance mutation suite: `444 cases passed`

| ID | Severity | Consolidated blocker |
| --- | --- | --- |
| `P14-R5-01` | P0 | Certificate validation durably removes the restart barrier before the caller's final snapshot comparison. A crash in that interval restarts with neither a barrier nor a pending certificate. |
| `P14-R5-02` | P0 | Cancellation during entry removal can occur after runtime retirement but before orphan-state and journal bookkeeping, allowing a replacement entry to begin without the inherited unknown-effect barrier. |
| `P14-R5-03` | P1 | Home Assistant stop initiation sets the domain stop flag but does not synchronously revoke dispatch; a request paused at final authorization can still issue a service call before asynchronous shutdown closes the runtime. |
| `P14-R5-04` | P1 | The snapshot regression does not mutate state while a supported target remains disabled, unexposed, or service-unavailable, so a candidate-like omission mutant survives the suite. |
| `P14-R5-05` | P2 | The construction-failure regression starts without a preexisting journal owner claim; replacing owner release with a no-op leaves all lifecycle tests green. |
| `P14-R5-06` | P2 | Governance, Noise, and Home Assistant subgates accept unrelated successful-child diagnostics, and the Home Assistant branch accepts a malformed identity marker, so the accepted transcript grammar remains open. |
| `P14-R5-07` | P2 | A successfully used certificate is consumed only in process memory. Its stale durable binding can reject later legitimate state drift or endpoint reauthentication before a fresh proof is consumed. |
| `P14-R5-08` | P2 | Stop after platform forwarding has published an entity rolls back the runtime without unloading the platform, leaving a stale conversation entity bound to a closed runtime. |
| `P14-R5-09` | P2 | Cancellation after Home Assistant begins platform unload can propagate before runtime and helper cleanup, retaining a runtime after the platform has already been removed. |

No P3 finding was reported. The platform rejected the first safety-review
prompt before a valid review began; that external failure consumed no review
round. A fresh independent safety reviewer completed the recorded role.

The exact role reports are `usr047-replacement-requirements.md`,
`usr047-replacement-correctness.md`,
`usr047-replacement-test-oracle.md`,
`usr047-replacement-risk.md`,
`usr047-replacement-reproducibility.md`, and
`usr047-replacement-runtime-adversarial.md`.

Under `USR-047`, the next correction is limited to these nine IDs, their
direct regressions, exact validator closure, and necessary governance
evidence. It adds no optional feature and weakens no hard requirement.
