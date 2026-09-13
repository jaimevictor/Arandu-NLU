# P15 Authorized Resumption

- Date: `2026-09-11`
- Authorization: `USR-045`
- Governing decision: `ADR-0047`
- Starting commit:
  `d1190c37b1429bbc4a7cf69e019ede6af33fd0a6`
- Starting tree:
  `d2e5bc637515fffa3d739a44fef4c2c68e34e0c9`
- State: `IMPLEMENTATION`

## Pass Unit

One resumed P15 convergence pass consists of a replacement P02 qualification
lineage frozen before behavior changes, one integrated correction of the
durability, helper-ownership, zero-plan, and evaluator-binding blockers, exact
P14 debt closure, native and real-runtime qualification, and deterministic
release production.

The replacement corpus freeze is a mandatory chronology boundary, not a
candidate review round. Until that commit exists, production, linguistic,
runtime-policy, protocol, adapter, and companion behavior remain byte-frozen.

## Minimum Acceptance

The pass is minimally acceptable only when:

- the replacement corpus regenerates byte for byte and its held-out and
  performance records remain sealed;
- every inherited P14 P0 through P2 finding has a direct regression and the
  complete P14 gate plus six independent reviews pass one exact baseline;
- P15 semantic, negative-suite, confidence, core-performance, warm
  end-to-end, native Linux amd64, native Linux arm64, and real Home Assistant
  lifecycle gates pass;
- deterministic companion and OCI artifacts, checksums, SPDX, notices,
  manifest, and bidirectional source reconciliation pass;
- the complete P15 validator passes one immutable candidate;
- all mandatory P15 reviewers pass that same candidate; and
- no P0 through P2 finding remains open.

## Immediate Action

Freeze and validate the new P02 qualification lineage without reading the old
or new held-out and performance records outside their generator and sealed
validation boundary. No behavior remediation may start before that immutable
freeze.

## Superseded P02-v2 Freeze

The replacement lineage is frozen at
`SELF_AT_P15_PRE_IMPLEMENTATION_COMMIT` and recorded in
`docs/evidence/P15-P02-V2-FREEZE.md`. That lineage was later invalidated by
ADR-0048 and is historical evidence only.

## P02-v2 Invalidation And V3 Restart

A bounded but over-broad repository search displayed P02-v2 performance
records after remediation began. Under ADR-0047, the executor stopped before
another repository change. `USR-046` and ADR-0048 permanently invalidate
P02-v2 for release qualification and authorize one clean P02-v3 restart from
the immutable pre-remediation baseline.

The pre-exposure remediation delta is preserved but is not a candidate. It
may be reapplied only after the P02-v3 lineage is frozen on an immutable
commit. P02-v3 held-out, performance, and suite record bytes remain sealed
from the executor and remediation agents.

## USR-047 Blob-Bound Final Replacement

Three P02-v3 freeze review rounds ended with one remaining P1: the source-I/O
baseline authenticated parent pathnames but not parent blob identities. No
lineage was committed and no product remediation was reapplied.

The user authorized one final blob-bound blocker-only replacement and
autonomous continuation through P15, P16, and FINAL without another scope
prompt. The replacement must bind parent path and blob identity, freeze every
future mutable I/O path before remediation, reproduce the final bypass, and
receive a fresh independent PASS before the immutable corpus checkpoint.

## Final P02-v3 Freeze Completion

The final P02-v3 candidate:

- blob-binds every inventoried project path to the authorization-parent tree;
- treats all 40 exact future mutable paths as potentially I/O-capable without
  syntax classification;
- binds Git inventory to the explicit repository and worktree;
- inventories extensionless and unknown-extension project paths;
- regenerates byte for byte;
- passes the sealed aggregate validator; and
- received an independent zero-finding `PASS` as subject
  `851d7e9be8647b1cf7b0be9a98e7a6c7d3b7cf886cb704dc1cd1384e594f1b0`.

The immutable freeze is commit
`a3c0a273f0d66d4bc1813fb12472dba7815dd178`, tree
`f2da7663c2321443633dd7496bd5db5b4987b1b3`. The next action is reapplication
of the preserved remediation using only v3 train, development, public
contracts, and other eligible non-release evidence.

## USR-047 P14 Replacement Review

P14 replacement commit `ba739823ffa7d55abc9042a62f4d5241108d1c49`,
tree `50a695d7cd0d81522d8d468fb0446fb857fee5df`, passed the complete exact gate
twice and the 444-case governance mutation suite. Five mandatory roles
returned `FAIL`; reproducibility returned `PASS`.

The nine exact blockers are frozen in
`docs/reviews/P14/usr047-replacement-blocker-summary.md`. Before restoring the
preserved P15 remediation, the executor must freeze this failed evidence,
correct only `P14-R5-01` through `P14-R5-09`, rerun the complete P14 gate
twice, and obtain six fresh `PASS` verdicts on one immutable subject.
