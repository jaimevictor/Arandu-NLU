# P15 P02-v2 Evaluation-Lineage Invalidation

- Date: `2026-09-10`
- Governing decision: `ADR-0048`
- Invalidated lineage: `project-authored-synthetic-ptbr-p15-v2`
- Pre-remediation commit:
  `3a07959ced6567d194589c3a0a9da6c6ef647e33`
- Result: `INVALIDATED_FOR_RELEASE_QUALIFICATION`

## Incident

After behavior remediation began, an executor repository-search command used
the broad path `data/project-authored/p02-v2`. Its bounded output displayed
several records from `performance.jsonl`. The command did not display
held-out records, run the NLU, or produce case-level evaluation results.

No repository byte was changed after the display. The executor immediately
stopped implementation, reported the violation, and requested the explicit
decision required by ADR-0047.

The exposed record content is intentionally not reproduced here.

## Containment

The uncommitted remediation delta was preserved reversibly as Git stash
object
`80481b1e25a32bdcf7402471df0098e7b4f12b89`. Generated
`crates/release-eval/target/` files were removed before preservation. The
working tree then returned to the exact immutable pre-remediation commit.

The stash is implementation material only. It is not an accepted candidate,
evaluation input, oracle, or evidence source. It may be reapplied only after
the P02-v3 pre-implementation freeze and must receive complete fresh
verification.

## Disposition

P02-v2 held-out, performance, and suite results are permanently ineligible
for P15 release qualification. P02-v3 must use new identities and bytes and
must freeze before any behavior-affecting delta is reapplied.
