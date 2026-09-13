# P14 Debt Reproducibility Review Carried By P15

- Role: `reproducibility`
- Analysis instance: `01a08caf-3b23-7c51-aa5b-82c5524cbe29`
- Review date: `2026-09-10`
- Subject commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Subject tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Authorized parent: `aeac316eafa065b8c36fece92afa9c6b333c2eea`
- Mode: independent, read-only
- Verdict: `FAIL`

## Reproduced Baseline

The exact subject, tree, and parent matched in a clean clone. Validator
self-tests, Ruby syntax checks, and `git diff --check` passed.

## Findings

### P1 — Exact-subject acceptance is incomplete

`docs/evidence/P14-VALIDATION.md` records an interrupted governance suite and
states that the complete gate and six reviews were not run.
`docs/phases/PROJECT-STATUS.md` leaves the baseline in `REVIEWING`. This
blocks P15 acceptance and FINAL, though not safe P15 implementation work.

### P1 — Native and real-runtime evidence is absent

Native Linux amd64 and aarch64 execution and real Home Assistant runtime
validation remain deferred with artifacts disabled. They must close in P15
before release.

### P2 — Raw exact-gate logs are not byte-deterministic

The companion runner emits elapsed time, the parser accepts arbitrary elapsed
values, and `run_command` reproduces the raw output. Otherwise identical
transcripts containing `0.01s` and `9.99s` both parsed to the same semantic
test identity. Semantic evidence can remain stable, but exact log bytes are
not reproducible.

## Classification

- P0: none
- P1: two
- P2: one
- P3: none

FAIL
