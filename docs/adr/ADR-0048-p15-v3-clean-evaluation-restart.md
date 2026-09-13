# ADR-0048: P15 v3 clean evaluation restart

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-10
- Owners: P15, P16, FINAL
- Supersedes: ADR-0047 only for its post-exposure terminal branch

## Context

ADR-0047 authorized one replacement P02-v2 evaluation lineage before the
integrated P14-P15 remediation. That lineage was frozen at
`3a07959ced6567d194589c3a0a9da6c6ef647e33`.

After remediation work began, an executor command intended to search
repository documentation and eligible data used an over-broad
`data/project-authored/p02-v2` path. The bounded command displayed several
P02-v2 performance records. It did not execute the NLU, disclose per-case
results, or expose held-out records, and no repository byte changed after the
display. Nevertheless, the access violated the P02-v2 sealed-split contract.
ADR-0047 therefore required P15 to stop for a new explicit user decision.

The user explicitly authorized invalidating P02-v2, freezing a clean P02-v3
lineage, reapplying the scoped remediation, and continuing through the
remaining phases.

## Decision

`USR-046` supersedes only ADR-0047's terminal stop caused by the recorded
P02-v2 performance exposure. P02-v2 is permanently ineligible for a release
qualification claim.

The repository must return to the immutable pre-remediation baseline
`3a07959ced6567d194589c3a0a9da6c6ef647e33`. The pre-exposure remediation
delta may be retained only as reversible implementation material. It is not a
candidate and cannot be evaluated until a new P02-v3 lineage is frozen in the
release branch before that delta is reapplied.

P02-v3 must:

- use new source, corpus, generator, case, family, split, and artifact
  identities;
- derive deterministic surfaces and semantics without reading or copying
  P02-v2 held-out, performance, or suite records;
- provide train, development, held-out, performance, and independent
  fail-closed suites under the same license and provenance constraints;
- prove byte regeneration and complete split separation;
- keep held-out, performance, and suite record bytes inaccessible to the
  executor and remediation agents;
- permit only its sealed aggregate runner to read release records after the
  remediation candidate freezes; and
- record the exact immutable pre-implementation commit and tree.

An isolated corpus writer may inspect the admitted v2 generator,
specification, train, and development material, but not v2 release-split or
suite records. Product-remediation agents must receive no v2 or v3 sealed
record content. The executor may inspect generator source, specification,
manifest aggregates, train, development, hashes, and validation results, but
not v3 release records.

The authorized remediation scope and every native, real Home Assistant,
licensing, packaging, review, and terminal requirement from ADR-0047 remain
unchanged. No result from P02-v2 may select, tune, or justify product
behavior.

## Acceptance

The restart is valid only when:

1. the v2 exposure is recorded without reproducing exposed record content;
2. the v3 lineage is frozen and validated on a commit descending directly
   from the pre-remediation baseline plus governance-only changes;
3. all behavior-affecting remediation is committed after that freeze;
4. static and runtime controls prove that only the sealed runner can read v3
   release records;
5. the complete P14 and P15 requirements from ADR-0047 pass on immutable
   subjects; and
6. P16 and FINAL proceed only after P15 passes.

Any v3 release-record exposure before candidate freeze, or any case-level
release output afterward, invalidates v3 and returns P15 to blocked under the
bounded-phase contract.

## Consequences

- P02-v2 remains historical provenance and failure evidence only.
- The saved pre-exposure implementation delta must be reapplied and reviewed
  after the v3 freeze; its earlier worktree chronology cannot authorize
  evaluation.
- The unavailable native Linux amd64 resource remains a mandatory external
  blocker unless a qualifying native executor is admitted.
