# P14 Adapter And Companion Report

- Phase: `P14`
- State: `BLOCKED_REVIEW_ROUND_BUDGET_EXHAUSTED`
- Subject: `f919aba0defb9c1d2bb773c7eef2b44071ccb17f`
- Subject tree: `d6bef59bc8ba9785ca6c245e014f1d8bf37d6388`
- Result: `FOUR_OF_SIX_REVIEW_FAIL`

## 2026-09-11 Post-Review Correction

The exact corrected subject passed the complete P14 gate twice. Both
transcripts were byte-identical at 246 lines, 21,208 bytes, and SHA-256
`773b509abe7645dc384e28568f9e31eccb7922d2781caf21e2d8cba9c0fa58e8`.
The gate reported 199 companion tests, eight metadata checks, 23 reconstructed
Noise packages, 222 passing Rust tests with three intentional ignores, and
all 38 Clippy targets.

The requirements and reproducibility reviewers returned `PASS`. Correctness,
test-oracle, risk, and runtime-adversarial returned `FAIL`. Seven consolidated
P0 through P2 findings cover malformed and concurrent removal, rollback
dispatch and partial unload, forged test execution evidence, cross-stream
gate output, and a non-exact governance count. The exact reports and ledger
are under `docs/reviews/P14/usr047-post-review-correction-*.md`.

This subject consumed the single post-review correction authorized by
ADR-0049 and the final bounded P14 review round. No P14 PASS is claimed.

## 2026-09-11 USR-047 Replacement Review

The complete exact-subject P14 gate passed twice with byte-identical
transcripts. Each transcript is 21,209 bytes, 246 lines, and has SHA-256
`bf53eb0e10e4054d069913022050bf74efa353fa0b5c3cd51180dec3279d57e4`.
The gate reported 199 companion tests, eight metadata checks, 23 reconstructed
Noise packages, 222 passing Rust tests with three intentional ignores, and
all 38 Clippy targets. The exhaustive governance mutation suite separately
passed all 444 cases.

Five of six independent reviewers nevertheless returned `FAIL`; the
reproducibility reviewer returned `PASS`. Their findings consolidate to two
P0, two P1, and five P2 classes covering crash-safe certificate consumption,
removal and stop cancellation, platform rollback, durable certificate
lifecycle, mutation coverage, and exact subgate output grammar. The exact
ledger and reproducible commands are under
`docs/reviews/P14/usr047-replacement-*.md`.

The prospective minimum-remediation authority in `USR-047` authorizes one
blocker-only correction of those nine IDs after this failed baseline and its
review evidence are frozen. No P14 PASS is claimed.

## Historical 2026-09-11 Resumed Review

The complete exact-subject P14 gate passed twice with byte-identical
transcripts. Each transcript is 21,163 bytes and has SHA-256
`857048940fa71275531405a88e2591c77b3c5704a0ff369e22f245846e96d743`.
The gate reported 187 companion tests, eight metadata checks, 23 reconstructed
Noise packages, 222 passing Rust tests with three intentional ignores, and
all 38 Clippy targets.

All six independent reviewers nevertheless returned `FAIL`. Their findings
consolidate to one P0 class, three P1 classes, and three P2 classes covering
complete and stable restart reconciliation, claimed-helper epoch ownership,
stop-during-forwarding rollback, journal-owner cleanup, proof-binding
regressions, and closed deterministic gate output. The exact ledger is
`docs/reviews/P14/resumed-blocker-summary.md`.

The user's newer explicit instruction to continue autonomously and authorize
every in-scope correction activates the `USR-047` amendment in ADR-0049. One
consolidated blocker-only replacement is authorized. No P14 PASS is claimed
until that replacement passes the complete gate and a fresh six-role review.

## Delivered

P14 implements the add-on adapter, companion integration, typed execution
boundary, bounded operation identity and reconciliation state, shared
fail-closed logical time, epoch-bound continuation handling, durable restart
barriers, helper-process cleanup, Home Assistant contract fixtures, and
selected Noise source promotion evidence.

The final remediation adds exact regressions for the fourteen blocker classes
recorded at
`aeac316eafa065b8c36fece92afa9c6b333c2eea`. P13-owned and closeout paths
remain byte-identical to the P14 entry checkpoint.

## Historical Validation And Transition

Before freeze, the remediation completed 141 companion tests, eight add-on
metadata checks, reconstruction of all 23 promoted Noise packages, 222
passing Rust tests with three intentional host-inapplicable ignores, one
passing harnessless target, all 38 Clippy targets, P14 validator self-tests,
Ruby syntax checks, and `git diff --check`.

The exhaustive governance mutation suite was interrupted during its YAML
failure mutations. The clean exact-subject P14 gate and all six mandatory
independent reviews were not run on `93ed8d75`. No P14 PASS or finding closure
is claimed from the preflight results.

On 2026-09-10 the user explicitly directed the executor to move to P15 now.
ADR-0044 therefore records this baseline as a user-directed transition
checkpoint while preserving the unrun validation as debt.

## P15 Carry-Forward

Before release artifact production or architecture enablement, P15 must:

- receive an explicit scope decision before any successor to the exhausted
  P14 correction, then close `P14-R6-01` through `P14-R6-07` and obtain a
  fresh exact-subject P14 gate plus unanimous six-role review;
- run the native Linux amd64 and aarch64 source, build, execution, process
  isolation, and reachability gates transferred by ADR-0039;
- run the supported real Home Assistant lifecycle and execution gates
  transferred by ADR-0040; and
- keep `addon/build-contract.json` fail-closed until those prerequisites and
  the P15-owned release gates pass.

This report records progression, not minimum phase acceptance.
