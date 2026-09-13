# P01 Pre-phase Requirements Analysis

- Role: `phase-requirements`
- Reviewer instance: `01a044c8-05f9-7d01-8936-feae3593b800`
- Input baseline: `ec2f05c4ecc0411b1ff010b31a5199de127cc413`
- Mode: read-only
- Result: `ANALYSIS_COMPLETE`

P01 owns 106 foundation rows plus `GLB-OUTCOME-001`, `ARC-CORE-001`,
and `ARC-CORE-002`. The mandatory implementation groups are:

- exact Rust 1.98.0, Edition 2024, lockfile, FOSS admission, and the
  standard-library-only `nlu-core` dependency boundary;
- immutable request input, source-bound checked half-open UTF-8 byte spans,
  opaque namespaced identifiers, bounded integer scores, and injected logical
  time and identifier traits;
- typed hypotheses, slots, entity references, ordered graph plans,
  clarifications, abstentions, and invalid-state rejection;
- distinct strict protocol DTOs, bounded closed errors, explicit limits,
  validated DTO-to-core conversion, and exactly four wire outcomes;
- UTF-8 JSON v1, fixed canonical field/tag ordering, strict duplicate,
  unknown, malformed, trailing, version, and graph rejection;
- versioned JSON Schemas, fixture conformance, ambient-state denial,
  deterministic replay, and non-linguistic `FIXTURE_TECNICA` tests.

The P01 slice of cross-phase text, safety, scope, determinism, build,
security, dependency, tool, scaffold, validation, and rollback requirements
must also be demonstrated. Those rows remain globally pending for later
owners.

## Minimum Acceptance

P01 has at most three frozen candidates. The first candidate that passes all
109 phase-close obligations, every applicable cross-phase slice, the exact
format, Clippy, test, build, offline dependency, source-boundary, canonical
byte, hostile-input, and two-clean-root reproducibility checks must be reviewed
on one immutable commit and checkpointed immediately. No P0-P2 finding may
remain; eligible P3 work is deferred.

## Preconditions And Findings

- **P1:** add a non-circular P01-to-P02 evidence-checkpoint validator before
  candidate freeze.
- **P1:** define the exact reproducible P01 artifact set and distinct-root
  comparison procedure.
- **P2:** document the protocol v1 decoder support window required by
  `P01-VER-008`.
- **P2:** ensure injected logical time and identifier creation cannot leak
  timestamps or random identifiers into semantic output.

No P0 contradiction was found.

## Counterexample

A plan field containing a raw Home Assistant service string, arbitrary JSON,
or an execution callback would simplify later integration but violates the
P01 plan, authority, and transport-independence requirements. P01 must expose
only authority-free typed semantic graph contracts.

Evidence inspected: `AGENTS.md`, `docs/clean-room/USER-DECISIONS.md`,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`, ADRs 0001, 0003, 0004,
0006, and 0008, plus both phase-state files. Commands used included `find`,
`grep`, `sed`, `awk`, `nl`, `git status`, and `git rev-parse`.
