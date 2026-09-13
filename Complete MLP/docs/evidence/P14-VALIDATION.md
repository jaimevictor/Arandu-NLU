# P14 Adapter And Companion Post-Review Correction Validation

- Phase: `P14`
- Candidate: `f919aba0defb9c1d2bb773c7eef2b44071ccb17f`
- Candidate tree: `d6bef59bc8ba9785ca6c245e014f1d8bf37d6388`
- Authorization base: `24be5d64282cc2226b870709f960110656cee008`
- Authorized parent: `24be5d64282cc2226b870709f960110656cee008`
- Substantive frozen review rounds consumed: `3 of 3`
- Post-review correction: `1 of 1 under ADR-0049`
- Validation time: `2026-09-11T17:23:31Z`
- Result: `EXACT_GATE_PASS_REVIEW_FAIL_ROUND_EXHAUSTED`
- Mandatory review result: `FOUR_FAIL_TWO_PASS`

## Post-Review Correction Exact-Subject Result

The complete gate was executed twice against the clean immutable candidate.
The transcripts at `/private/tmp/nlu-p14-gate-f919aba-run1.txt` and
`/private/tmp/nlu-p14-gate-f919aba-run2.txt` were byte-identical:

- bytes: `21208`;
- lines: `246`;
- SHA-256:
  `773b509abe7645dc384e28568f9e31eccb7922d2781caf21e2d8cba9c0fa58e8`;
- companion tests: `199`;
- add-on metadata checks: `8`;
- reconstructed Noise packages: `23`;
- Rust tests: `222` passed and `3` intentionally ignored; and
- Clippy targets: `38`.

One sandboxed attempt was excluded after local Unix-socket creation was
denied with `EPERM`. Both counted runs used the admitted host boundary and
completed the exact gate.

Six distinct read-only reviewers inspected the same commit and tree.
Requirements and reproducibility returned `PASS`. Correctness, test-oracle,
risk, and runtime-adversarial returned `FAIL`. The seven unique P0 through P2
findings and reproduction evidence are frozen in
`docs/reviews/P14/usr047-post-review-correction-blocker-summary.md` and its
six role reports. The executor independently reproduced the decisive
malformed-removal, concurrent-removal, rollback-dispatch, partial-unload,
forged-test-execution, cross-stream, and governance-count counterexamples.
This evidence does not claim P14 acceptance.

## Historical USR-047 Replacement Exact-Subject Result

The complete gate was executed twice against the clean immutable candidate.
The transcripts were byte-identical:

- bytes: `21209`;
- lines: `246`;
- SHA-256:
  `bf53eb0e10e4054d069913022050bf74efa353fa0b5c3cd51180dec3279d57e4`;
- companion tests: `199`;
- add-on metadata checks: `8`;
- reconstructed Noise packages: `23`;
- Rust tests: `222` passed and `3` intentionally ignored;
- Clippy targets: `38`; and
- governance mutation cases: `444` passed.

Six distinct read-only reviewers inspected the same commit and tree. The
requirements, correctness, test-oracle, safety, and runtime-adversarial roles
returned `FAIL`; reproducibility returned `PASS`. The nine unique P0 through
P2 findings and exact reproduction commands are frozen in
`docs/reviews/P14/usr047-replacement-blocker-summary.md` and its six role
reports. This evidence does not claim P14 acceptance.

## Historical Resumed Exact-Subject Result

The complete gate was executed twice against the clean immutable candidate.
The transcripts were byte-identical:

- bytes: `21163`;
- lines: `246`;
- SHA-256:
  `857048940fa71275531405a88e2591c77b3c5704a0ff369e22f245846e96d743`;
- companion tests: `187`;
- add-on metadata checks: `8`;
- reconstructed Noise packages: `23`;
- Rust tests: `222` passed and `3` intentionally ignored;
- Clippy targets: `38`.

Six distinct read-only reviewers then inspected the same commit and tree.
Every reviewer returned `FAIL`. The consolidated findings are frozen in
`docs/reviews/P14/resumed-blocker-summary.md`. Under the user's newer
instruction and the ADR-0049 inherited-debt amendment, one blocker-only
replacement is authorized. This evidence does not claim P14 acceptance.

## Historical Scope

ADR-0043 and `USR-043` authorize this one final integrated remediation of
the fourteen blocker classes recorded at
`aeac316eafa065b8c36fece92afa9c6b333c2eea`. The candidate changes no P13
owned or closeout byte, dependency, linguistic input, source selection,
optional feature, or P15-owned artifact/runtime gate.

The correction adds a bounded non-evicting operation-identity registry,
per-epoch sequential IDs and explicit retries, companion high-water
rejection, per-effect reconciliation evidence, separate bounded
reconciliation probes with two-cohort retry permits, a shared
exception-catching monotonic clock, durable pre-dispatch restart barriers,
epoch-revision checks across helper awaits, and post-exit-only helper endpoint
cleanup. Governance, host-tool rights, and historical/current Noise schema
bindings are exact and machine checked.

## Historical Verification

The pre-freeze candidate tree completed:

- 141 dependency-free companion tests under admitted CPython 3.9.6 with
  isolated import roots, exact identities, no skips, and Unix socket tests
  run outside the restricted execution sandbox;
- 8 add-on metadata and disabled-artifact checks;
- exact Home Assistant 2026.8.3 source identity at commit
  `759e4658f40b3ccb671d418b8a0ed95224bf4561` and tree
  `f4a72534bb33abf8b5d183910a0c134b968af2f8`;
- deterministic replay of all 23 promoted Noise source packages;
- 222 passing Rust tests, 3 intentional macOS-inapplicable ignores, one
  passing harnessless target, zero failed binaries, and all 38 Clippy targets;
- P14 validator self-tests, Ruby syntax checks, and `git diff --check`; and
- byte identity for the 45 P13-owned and P13-closeout paths against
  `1699b57d0aee6eba76783fa961598717988912e3`.

The exhaustive governance mutation suite was terminated during its
`yaml_failures` mutation family after the normative aggregate and exact
validator digest had been corrected. No PASS is claimed for that suite. The
complete clean exact-subject gate and the six mandatory independent reviews
were not run before the user directed the executor to move to P15.

The Home Assistant latest-release response remains mutable historical
evidence. The exact-subject gate therefore accepts its frozen fallback only
when the previously validated source identity, historical blobs, ancestry,
pinned checkout, and disabled P15 build contract all remain exact.

## Accepted Transfers

ADR-0039 retains native Linux amd64/aarch64 build and execution in P15.
ADR-0040 retains real Home Assistant runtime execution in P15. Neither is
claimed as passed. `addon/build-contract.json` keeps artifact production and
both architectures disabled pending P15 admission.

## Candidate Bound

Commit `f919aba0defb9c1d2bb773c7eef2b44071ccb17f`, tree
`d6bef59bc8ba9785ca6c245e014f1d8bf37d6388`, is retained as immutable failed
review evidence. It consumed the post-review correction and the final bounded
P14 review round. No successor product candidate is authorized without a
newer explicit scope decision. Product artifacts remain disabled and no final
release claim is permitted.
