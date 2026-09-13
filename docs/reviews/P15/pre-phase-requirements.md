# P15 Pre-Phase Requirements Analysis

- Phase: `P15`
- Role: `independent-requirements-analysis`
- Analysis instance: `01a08c7c-d728-7f80-b626-906ee131b19a`
- Input commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Input tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Mode: read-only independent primary-evidence inspection
- Result: `READY_WITH_SEPARATE_UNRESOLVED_P14_DEBT`

## Baseline Truth

P14 is not claimed `PASS`. Its evidence records only a preflight result. The
exhaustive governance mutation suite was interrupted, the clean exact-subject
gate was not run, and the six mandatory reviews were not run.

The unrun exact-subject command is:

```text
tools/validate-p14 --expected-commit 93ed8d75a4cb35f80572f8207105929b0071f48e --expected-tree 896a220ebb3e18905c2fc79d18779eecf547931c
```

That gate, `tools/test-validate-governance`, and the six-role review set remain
separate P14 and FINAL debt. P15 evidence cannot retroactively convert them
into a P14 pass.

## Direct P15 Obligations

The matrix contains 40 direct pending `P15-*` requirements:

- `P15-EVAL-001..012`: intent, slot, entity, graph, clarification, abstention,
  false-plan, clean-text, ASR-noise, negative-suite, metric-version, and
  isolation reporting;
- `P15-PERF-001` and `P15-GATE-001`: raw timing and resource samples plus
  provenance for every release threshold;
- `P15-PKG-001..011`: per-architecture reproducibility, SBOM, notices,
  checksums, installation, upgrade, leak-free rollback, add-on declarations,
  companion packaging, and release-input hashes;
- `P15-ARCH-001..003`: native `amd64` and `aarch64` support with fail-closed
  architecture admission;
- `P15-LIFE-001..005`: dual-deliverable install, removal, upgrade, restart and
  re-pairing, and rollback;
- `P15-COV-001..004`: complete domain, operation, capability, catalog, and
  actionable coverage reporting; and
- `P15-LIC-001..002` and `P15-ROLL-001`: release licensing and replaceable
  packaging.

## Inherited Mandatory Obligations

After adding `USR-044`, owner expansion across `All`, comma-separated owners,
and phase ranges yields 495 inherited P15 rows: 492 pending, two satisfied
word-count rows, and one waived independent-accuracy claim. Together with the
40 direct rows, P15 has 535 applicable rows, 532 of them pending at entry.
The 98.4% project-authored internal conformance gates remain mandatory even
though an independent-accuracy claim is waived.

The inherited scope includes:

- user, product, clean-room, source, licensing, dependency, tooling,
  orchestration-exclusion, and no-external-model requirements;
- deterministic semantic, adapter, protocol, build, offline, privacy,
  persistence, logging, security, and evidence envelopes;
- the complete accuracy, Wilson-bound, per-stratum, false-plan, performance,
  latency, throughput, memory, startup, size, hardware, held-out-isolation,
  reporting, and rollback contracts;
- Home Assistant carry-forward rows `P10-HA-023`, `P10-HA-025`,
  `P10-ROLL-001..002`, `P13-AUTH-012`, and `P14-ROLL-001..003`; and
- every applicable agent, review, phase-loop, state, continuation-guard,
  validation, and terminal-operation discipline row.

## Transfer Gates

| Item | Required P15 proof |
| --- | --- |
| Native Linux transfer under ADR-0039 | Build and execute the exact selected channel on actual Linux `amd64` and `aarch64` from kernel-enforced read-only source; prove process isolation, exact source-to-binary closure, and rejected-source unreachability. |
| Real Home Assistant transfer under ADR-0040 | Admit the complete FOSS runtime and dependency closure; run pinned Home Assistant 2026.8.3 and a frozen later release identity in clean instances; prove installation, restart and re-pair, upgrade, rollback, backup boundaries, and removal. |
| P14 validation debt under ADR-0044 | Keep the P14 exact-subject gate, exhaustive governance mutation suite, and six reviews separate. Native or real-runtime success does not satisfy them. |

`P14-HA-009`, `P14-HA-010`, `P14-GATE-001`, and their real-runtime
dependents remain unsatisfied until the transferred real-runtime gate closes.

## Required Disabled State

Before enablement, `addon/build-contract.json` must retain:

- `artifact_build_allowed: false`;
- both architectures as `disabled_pending_admission`;
- no production Dockerfile or container recipe;
- `network_fetch_allowed: false`; and
- reason code `P15_CONTAINER_INPUTS_NOT_ADMITTED`.

`docs/evidence/P14-NOISE-SOURCE-PROMOTION.md` remains
`PROMOTED_PENDING_NATIVE_LINUX_ADMISSION`. Host-only, cross-compiled, emulated,
or mock-only evidence cannot enable an architecture or distributable artifact.

## Convergence Pass And Minimum Acceptance

One convergence pass is one integrated release-qualification approach whose
runtime, tool, root-filesystem or base-image portfolio, evaluation and
benchmark runners, native packaging, Home Assistant lifecycle proof, P14-debt
treatment, and release evidence are selected together and then frozen,
dispositioned, or rejected.

The pre-candidate budget is at most three passes. Routine retries and external
platform failure before a valid pass do not consume one. Candidate review
allows one initial subject and at most two blocker-only replacements.

Minimum acceptance requires:

1. every direct and applicable inherited mandatory row passing, with no
   substitute check presented as the original;
2. both transferred native and real-runtime gates passing;
3. complete conformance, per-stratum, zero-false-plan, and performance gates
   without unsupported claims;
4. reproducible architecture-specific artifacts, lifecycle tests, SBOM,
   notices, checksums, source inventory, and privacy scans;
5. one complete exact-subject P15 gate on a clean immutable candidate;
6. requirements, correctness, test-oracle, risk, reproducibility, and
   runtime-adversarial reviewers all returning `PASS` on that candidate;
7. no open P0 through P2 finding and only eligible recorded P3 residuals; and
8. immediate checkpointing of the first minimally acceptable baseline.

No `tools/validate-p15*` exists at entry, so the exact P15 gate is itself a
mandatory deliverable before candidate freeze.

## Counterexample

Treat the 141 companion tests, 222 Rust tests, host-only source promotion,
cross-compiled targets, and deterministic Home Assistant mocks as sufficient,
then enable both architectures.

Rejected: none proves native Linux execution, native process controls, real
Home Assistant compatibility, or an admitted runtime closure. Artifact
production and both architectures must remain disabled, and P14 remains
without a PASS.

## Primary Evidence

The analysis inspected `AGENTS.md`, the user-decision and requirement ledgers,
ADR-0001, ADR-0002, ADR-0005 through ADR-0008, ADR-0019, ADR-0022,
ADR-0037 through ADR-0040, ADR-0043, P13 and P14 phase evidence, all P14
pre-phase records, `addon/build-contract.json`, and the Noise promotion
evidence.

Representative commands used exact-commit `git show`, commit and tree
resolution, tool-path inventory, and requirement-row owner expansion. No
write, network, sibling, prohibited-source, or execution-oracle access
occurred.
