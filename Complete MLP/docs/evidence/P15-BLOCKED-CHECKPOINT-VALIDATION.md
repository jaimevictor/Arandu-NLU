# P15 Blocked Checkpoint Validation

- Date: `2026-09-10`
- Subject commit:
  `f8af02a8525e8c76c2be140ccf764964d5a4763e`
- Subject tree:
  `5395ef10fa3e45f6abf4dee68add3e8c01204470`
- Subject state: `P15 BLOCKED`
- Result: `CHECKPOINT_GOVERNANCE_PASS_RELEASE_GATE_FAIL`

## Exact Governance

The exact governance validator ran from a clean, single-branch, no-tag clone
of the subject. It bound the subject commit and tree, the frozen normative
rows, and SHA-256 values for all four governance validator and self-test
files.

Observed terminal output:

```text
governance validation passed (commit f8af02a8525e8c76c2be140ccf764964d5a4763e, tree 5395ef10fa3e45f6abf4dee68add3e8c01204470, rows 0d94e49105e8e480eff6922331507217f3866c9675def0e24dc4bdb5e2921187, 1515 requirements)
```

## Tooling Checks

The following checks passed without reopening the real held-out or
performance splits:

- `release-eval`: 22 offline fixture-only tests;
- `release-eval`: strict Clippy with warnings denied;
- `release-eval`: rustfmt check;
- `release-packager`: 22 offline tests;
- `release-packager`: strict Clippy with warnings denied;
- `release-packager`: rustfmt check;
- `tools/test-validate-p15`; and
- Ruby syntax checks for the P15 validator and self-test sources.

The evaluator source-scan regression passed and rejects test-time calls to
the sealed corpus loaders and release evaluation entry points.

## Release Gate

The exact P15 validator correctly failed closed:

```text
P15_GATE_FAIL[P15_EVALUATION_REPORT_MISSING]: release/p15/evidence/evaluation-report.json is missing
```

That failure is required for this blocked subject. It does not supersede the
zero-plan aggregate, inherited P14 safety findings, invalidated evaluation
lineage, or absent native Linux and real Home Assistant evidence. No P15
phase pass, P16 entry, FINAL entry, artifact enablement, or release-readiness
claim is made.
