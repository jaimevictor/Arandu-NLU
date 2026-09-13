# Architecture Decision Records

ADRs are immutable decision records. A superseding ADR links to the earlier
record instead of rewriting its history.

Statuses used by this project:

- `ACCEPTED_AUTONOMOUS`: adopted under the user's delegated local-development
  authority.
- `SUPERSEDED`: replaced by a later ADR.
- `REJECTED`: considered and not adopted.

| ADR | Decision | Status |
| --- | --- | --- |
| [0001](ADR-0001-clean-room-and-foss-policy.md) | Clean-room and FOSS-only policy | ACCEPTED_AUTONOMOUS |
| [0002](ADR-0002-product-scope-and-ha-coverage.md) | Product scope and Home Assistant coverage | ACCEPTED_AUTONOMOUS |
| [0003](ADR-0003-rust-core-architecture.md) | Rust core architecture and invariants | ACCEPTED_AUTONOMOUS |
| [0004](ADR-0004-versioned-json-protocol.md) | Versioned strict JSON protocol | ACCEPTED_AUTONOMOUS |
| [0005](ADR-0005-quality-performance-contract.md) | Quality and performance contract | ACCEPTED_AUTONOMOUS |
| [0006](ADR-0006-baseline-and-review-evidence.md) | Immutable baselines and review evidence | ACCEPTED_AUTONOMOUS |
| [0007](ADR-0007-home-assistant-integration-contract.md) | Home Assistant integration contract | ACCEPTED_AUTONOMOUS |
| [0008](ADR-0008-deterministic-envelope.md) | Deterministic and reproducible envelopes | ACCEPTED_AUTONOMOUS |
| [0009](ADR-0009-deterministic-data-pipeline.md) | Deterministic data pipeline and package format | ACCEPTED_AUTONOMOUS |
| [0010](ADR-0010-unicode-normalization-and-span-mapping.md) | Unicode normalization and reversible span mapping | ACCEPTED_AUTONOMOUS |
| [0011](ADR-0011-auditable-tokenization.md) | Auditable source-bounded tokenization | ACCEPTED_AUTONOMOUS |
| [0012](ADR-0012-provenance-bearing-lexicon-package.md) | Provenance-bearing lexicon package | ACCEPTED_AUTONOMOUS |
| [0013](ADR-0013-lexical-evidence-morphology-evaluation.md) | Lexical-evidence morphology and isolated evaluation | ACCEPTED_AUTONOMOUS |
| [0014](ADR-0014-conservative-contextual-pos.md) | Conservative contextual POS and isolated training/evaluation | ACCEPTED_AUTONOMOUS |
| [0015](ADR-0015-evidence-bearing-intent-recognition.md) | Evidence-bearing intent recognition and pre-resolution evaluation | ACCEPTED_AUTONOMOUS |
| [0016](ADR-0016-home-assistant-catalog-and-resolution.md) | Home Assistant catalog and exact-evidence resolution | ACCEPTED_AUTONOMOUS |
| [0017](ADR-0017-evidence-bound-plan-composition.md) | Evidence-bound semantic plan composition | ACCEPTED_AUTONOMOUS |
| [0018](ADR-0018-bounded-session-continuation.md) | Bounded session continuation | ACCEPTED_AUTONOMOUS |
| [0019](ADR-0019-policy-protocol-v2-and-local-server.md) | Deny-first policy, complete protocol v2, and credential-free local server | ACCEPTED_AUTONOMOUS |
| [0020](ADR-0020-conditional-transport-source-remediation.md) | Conditional transport source remediation | ACCEPTED_AUTONOMOUS |
| [0021](ADR-0021-reject-cpython-openssl-transport-portfolio.md) | Reject the CPython and OpenSSL transport portfolio | ACCEPTED_AUTONOMOUS |
| [0022](ADR-0022-noise-snow-transport-portfolio.md) | Noise and Snow transport portfolio | ACCEPTED_AUTONOMOUS |
| [0023](ADR-0023-compile-only-transport-source-projection.md) | Compile-only transport source projection and project Poly1305 backend | ACCEPTED_AUTONOMOUS |
| [0024](ADR-0024-projected-origin-notice-closure.md) | Projected origin-notice and license-election closure | ACCEPTED_AUTONOMOUS |
| [0025](ADR-0025-p13-source-evidence-closeout-boundary.md) | P13 source-evidence closeout boundary | ACCEPTED_AUTONOMOUS |
| [0026](ADR-0026-direct-p13-validation-closeout.md) | Direct P13 validation closeout | ACCEPTED_AUTONOMOUS |
| [0027](ADR-0027-bounded-p13-review-correction.md) | Bounded P13 review correction | ACCEPTED_AUTONOMOUS |
| [0028](ADR-0028-exact-rust-toolchain-source-closure.md) | Exact Rust toolchain source closure | ACCEPTED_AUTONOMOUS |
| [0029](ADR-0029-dedicated-process-deadline-containment.md) | Dedicated-process deadline containment | ACCEPTED_AUTONOMOUS |
| [0030](ADR-0030-scheduler-conditional-containment-and-artifact-retention.md) | Scheduler-conditional containment and artifact retention | ACCEPTED_AUTONOMOUS |
| [0031](ADR-0031-terminal-p13-evidence-and-request-order-closure.md) | Terminal P13 evidence and request-order closure | ACCEPTED_AUTONOMOUS |
| [0032](ADR-0032-bounded-p13-archive-and-copied-source-closure.md) | Bounded P13 archive and copied-source closure | ACCEPTED_AUTONOMOUS |
| [0033](ADR-0033-exact-path-source-rights-and-governance-closure.md) | Exact path-source rights and governance closure | ACCEPTED_AUTONOMOUS |
| [0034](ADR-0034-bounded-source-review-closeout.md) | Bounded source-review closeout | ACCEPTED_AUTONOMOUS |
| [0035](ADR-0035-terminal-validator-and-evidence-closeout.md) | Terminal validator and evidence closeout | ACCEPTED_AUTONOMOUS |
| [0036](ADR-0036-final-p13-source-and-governance-closeout.md) | Final P13 source and governance closeout | ACCEPTED_AUTONOMOUS |
| [0037](ADR-0037-p14-adapter-companion-boundary.md) | P14 adapter and companion boundary | ACCEPTED_AUTONOMOUS |
| [0038](ADR-0038-p14-helper-bootstrap.md) | P14 companion-helper bootstrap | ACCEPTED_AUTONOMOUS |
| [0039](ADR-0039-p14-host-validation-boundary.md) | P14 host validation boundary | ACCEPTED_AUTONOMOUS |
| [0040](ADR-0040-p14-real-ha-runtime-transfer.md) | P14 real Home Assistant runtime transfer | ACCEPTED_AUTONOMOUS |
| [0041](ADR-0041-bounded-p14-blocker-closeout.md) | Bounded P14 blocker closeout | ACCEPTED_AUTONOMOUS |
| [0042](ADR-0042-terminal-p14-correction.md) | Terminal P14 correction | ACCEPTED_AUTONOMOUS |
| [0043](ADR-0043-final-p14-blocker-remediation.md) | Final P14 blocker remediation | ACCEPTED_AUTONOMOUS |
| [0044](ADR-0044-p14-user-directed-p15-transition.md) | P14 user-directed transition to P15 | ACCEPTED_AUTONOMOUS |
| [0045](ADR-0045-p15-release-qualification-and-source-portfolio.md) | P15 release qualification and source portfolio | ACCEPTED_AUTONOMOUS |
| [0046](ADR-0046-release-and-terminal-baseline-state-model.md) | Release and terminal baseline state model | ACCEPTED_AUTONOMOUS |
| [0047](ADR-0047-p14-p15-authorized-remediation-and-evaluation-refreeze.md) | P14-P15 authorized remediation and evaluation refreeze | ACCEPTED_AUTONOMOUS |
| [0048](ADR-0048-p15-v3-clean-evaluation-restart.md) | P15 v3 clean evaluation restart | ACCEPTED_AUTONOMOUS |
| [0049](ADR-0049-p15-blob-bound-final-evaluation-freeze.md) | P15 blob-bound final evaluation freeze | ACCEPTED_AUTONOMOUS |
