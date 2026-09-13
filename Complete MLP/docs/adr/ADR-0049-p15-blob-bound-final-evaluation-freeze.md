# ADR-0049: P15 blob-bound final evaluation freeze

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-11
- Owners: P15, P16, FINAL
- Supersedes: ADR-0048 only for its exhausted P02-v3 freeze-review branch

## Context

The clean P02-v3 lineage authorized by ADR-0048 passed deterministic
generation, aggregate validation, split-separation, bounded-capture, source
inventory, and sealed-access checks. Three independent review rounds then
reproduced progressively narrower source-confinement defects. The final
round proved that the authorization-parent baseline retained only pathnames:
new bytes at an old pathname could reconstruct a sealed path without lexical
markers and remain accepted.

The executor stopped without committing the lineage or reapplying product
remediation. The failed round-three bytes remain reversible evidence in a
separate Git stash. The user then explicitly authorized continuing through
P15, P16, and FINAL without further scope prompts and authorized all
in-scope blocker remediation while preserving the hard project boundaries.

## Decision

`USR-047` authorizes one exceptional blocker-only replacement of the exhausted
P02-v3 freeze candidate and prospectively authorizes the executor to perform
the minimum in-scope blocker corrections needed through FINAL without another
scope prompt.

The replacement must bind every authorization-parent I/O-capable source to
its immutable Git blob identity, not only its pathname. A changed or new
I/O-capable source is admissible only when its exact path was predeclared
before the P02-v3 freeze and it carries the applicable release or non-release
boundary marker. Tests must reproduce mutation of a parent-existing pathname,
sub-token and numeric path construction, repository excludes, and hidden
untracked sources.

This authorization does not waive or weaken:

- sealed held-out, performance, or suite access;
- clean-room, FOSS, provenance, licensing, or Amazon exclusion;
- deterministic regeneration and fail-closed semantics;
- native Linux amd64 and arm64 qualification;
- real supported Home Assistant lifecycle qualification;
- immutable candidate review, packaging, reconciliation, or terminal audit;
- the prohibition on optional refinement after minimum acceptance.

If an external prerequisite is genuinely unavailable, the executor records
the truthful blocker and continues every independent remaining action. It
must not substitute emulation, cross-compilation, mock-only evidence, or an
unreviewed runtime for a mandatory result.

## Acceptance

The exceptional replacement is acceptable only when:

1. parent source paths and blob identities are parsed with strict bounded
   framing and current bytes reproduce the bound blob identity;
2. every future mutable I/O path is frozen in the pre-remediation
   specification and requires its boundary marker when changed or created;
3. both Git ignore mechanisms and replacement objects cannot hide or rewrite
   the reviewed inventory;
4. the complete P02-v3 gate and a fresh independent adversarial review pass
   the exact same uncommitted bytes;
5. one immutable pre-remediation commit freezes the lineage before product
   remediation is restored; and
6. P15 resumes immediately after that checkpoint.

## Consequences

- The round-three P02-v3 bytes are failed evidence, not a release lineage.
- The replacement is blocker-only and creates no optional refinement budget.
- The saved product remediation remains ineligible until the new immutable
  freeze commit exists.
- The executor continues autonomously to the furthest truthful terminal state.

## 2026-09-11 inherited-P14-debt amendment

After the P02-v3 checkpoint and the first resumed P14 replacement were frozen,
all six independent P14 reviewers rejected exact subject
`7c22c9e3dad3b4cfc0d44a02553ff9cb93c0f2e7`, tree
`f4e1e6bb1a6222391aad0f670de30d81d871adcf`. The user then explicitly
instructed the executor to continue through the end without another scope
prompt and authorized every in-scope correction.

The prospective blocker-remediation authority in `USR-047` therefore applies
to one consolidated inherited-P14-debt replacement limited to the seven
reviewed blocker IDs in
`docs/reviews/P14/resumed-blocker-summary.md`. This amendment supersedes
ADR-0043's terminal stop only for those exact findings. It adds no optional
refinement and does not weaken sealed-data, native-Linux, real-Home-Assistant,
licensing, provenance, deterministic-gate, or same-subject review
requirements.

The replacement must freeze once, pass the complete deterministic P14 gate,
and receive fresh independent `PASS` verdicts from all six mandatory roles
before the inherited P14 debt is closed.

## 2026-09-11 pre-review gate-integration correction

The consolidated replacement froze as commit
`386819483852f0c910243cad07ae90084fdd6f18`, tree
`bcd4d2013f9852795267871042a96cb846448d80`. Its first exact-subject gate
stopped before product validation or independent review because the inherited
project-status validation marker omitted the governance validator's mandatory
UTC time component.

Under `USR-047`, one minimum child correction is authorized for this
pre-review integration defect. The failed subject remains immutable. The
successor must have `386819483852f0c910243cad07ae90084fdd6f18` as its
immediate parent, while its remediation scope is measured from the original
authorization base
`ea29e05368636a2c703b223b26828482dca4b1e9`. Beyond the previously authorized
product, regression, and P14-validator paths, the child may change only this
ADR, `docs/phases/PROJECT-STATUS.md`, and the governance validator's frozen
normative-file digest binding required by that status correction.

The child receives no optional behavior work or weakened gate. It must pass
the complete deterministic P14 gate twice and receive fresh independent
`PASS` verdicts from all six mandatory roles on one exact commit and tree.

## 2026-09-11 post-review minimum correction

The integration-corrected child froze as commit
`ba739823ffa7d55abc9042a62f4d5241108d1c49`, tree
`50a695d7cd0d81522d8d468fb0446fb857fee5df`. Its complete P14 gate passed
twice with byte-identical transcripts, and the exhaustive governance mutation
suite passed 444 cases. Five of six mandatory reviewers nevertheless returned
`FAIL`; the reproducibility reviewer returned `PASS`.

The nine unique findings are frozen in
`docs/reviews/P14/usr047-replacement-blocker-summary.md`. Under the
prospective authority already granted by `USR-047`, one minimum blocker-only
correction is authorized for exactly `P14-R5-01` through `P14-R5-09`, their
direct regressions, exact validator closure, and necessary evidence. This
supersedes the prior stop branch only for those reproduced findings and does
not create optional refinement.

A dedicated evidence commit must freeze this failed review before product
bytes change. The correction must use that evidence commit as its immediate
parent, freeze one immutable candidate, pass the complete deterministic P14
gate twice, and receive fresh independent `PASS` verdicts from all six roles.
No sealed-data, FOSS, clean-room, native-Linux, real-Home-Assistant, or
artifact requirement is waived.

## 2026-09-11 post-review correction round exhaustion

The authorized correction froze as commit
`f919aba0defb9c1d2bb773c7eef2b44071ccb17f`, tree
`d6bef59bc8ba9785ca6c245e014f1d8bf37d6388`. Its complete P14 gate passed
twice with byte-identical 246-line, 21,208-byte transcripts at SHA-256
`773b509abe7645dc384e28568f9e31eccb7922d2781caf21e2d8cba9c0fa58e8`.

The requirements and reproducibility reviewers returned `PASS`. The
correctness, test-oracle, risk, and runtime-adversarial reviewers returned
`FAIL`. Seven consolidated findings are frozen in
`docs/reviews/P14/usr047-post-review-correction-blocker-summary.md`: two P0,
two P1, and three P2 findings covering removal safety, rollback ordering,
test-execution evidence, and exact subgate output.

This subject consumed the single post-review correction authorized above and
the third substantive frozen P14 review round. Under the bounded phase
contract, P14 is blocked and no successor product candidate is authorized
without a newer explicit scope decision. The failed candidate remains
immutable, and the preserved P15 remediation remains ineligible.
