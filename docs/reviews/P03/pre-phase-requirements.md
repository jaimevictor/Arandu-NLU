# P03 Pre-phase Requirements Analysis

- Role: `executor-requirements-synthesis`
- Analysis instance: `p03-executor-requirements-20260828`
- Input baseline: `fb1d88b`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Scope

P03 owns 17 phase-specific rows and the P03 portion of the shared data
manifest, split, fail-closed import, and selective-removal rows. It must create
a real workspace component with functional `fetch`, `verify`, `import`,
`normalize`, `validate`, `split`, and `compile` commands. A source-ID removal
operation is also required even though it is not listed as a named command.

The only usable linguistic source is the P02
`PROJECT_AUTHORED_SYNTHETIC` package. P03 does not revive rejected external
sources, invent an upstream public URL, or convert the project-authored corpus
into an independently admitted source. External-source-only manifest fields
must have explicit non-applicable dispositions in the project-authored
variant; no missing or assumed field is accepted.

P03 must:

- keep ordinary builds and validation offline and make acquisition an explicit
  command with an explicit authorization flag;
- verify manifest schema, admission state, license, path, byte size, and
  SHA-256 before imported bytes become usable;
- preserve every source ID and reject unknown, technical-fixture, or
  unauthorized AI-origin linguistic records;
- canonicalize JSONL deterministically without changing string values;
- retain the P02 frozen split and reject a family assigned to multiple splits;
- compile a byte-stable package independent of input enumeration or record
  order;
- remove every direct and derived record for a requested source ID;
- reproduce identical output hashes in two distinct clean directories.

P03 does not add linguistic rules, alter P02 labels or quotas, run conformance
accuracy, implement runtime package loading, or fetch an external source.

## Minimum Acceptance

Pre-candidate convergence is limited to three integrated approaches. This
analysis selects the first approach: one `nlu-data` Rust package using only the
already admitted Serde closure and the standard library.

The first P03 candidate is frozen immediately when:

1. all named commands have executable positive and negative tests;
2. verification precedes import and rejects every required manifest defect;
3. normalization, split, compilation, and removal replays pass;
4. input-order permutation and two-directory output hashes match;
5. P01 and P02 inherited gates still pass;
6. no P0-P2 implementation finding remains.

At most three frozen candidates are permitted. Rounds two and three may only
repair reproduced blockers. No optional format expansion, external downloader,
compression, performance tuning, or additional source support extends P03.

## Findings

- **P1:** eligible independent pre-phase instances are unavailable. These
  executor syntheses do not satisfy `REV-PRE-001` through `REV-PRE-003`.
- **P1:** a project-authored manifest variant must distinguish explicit
  non-applicability from missing external-source evidence.
- **P1:** compilation must never expose held-out case contents in logs or
  command summaries.
- **P2:** implementing network transport without an admitted need or source
  would increase risk and is outside minimum acceptance.

## Counterexample

A command that copies the P02 directory and hashes only its final output is not
a data pipeline. It could accept a modified input, discard provenance, leak a
family across splits, and still reproduce the same bad package. Verification
must bind input bytes before import, and each later stage must validate its own
lineage.

Evidence inspected: `AGENTS.md`, `docs/clean-room/SOURCE-POLICY.md`,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`, ADRs 0001, 0005, 0006, and 0008,
the P02 manifest and validation evidence, workspace manifests, and phase state.
Commands were read-only `find`, `grep`, `sed`, Ruby inventory, and Git
inspection.
