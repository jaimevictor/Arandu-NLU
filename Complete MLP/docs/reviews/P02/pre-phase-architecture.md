# P02 Pre-phase Architecture Analysis

- Role: `executor-architecture-synthesis`
- Analysis instance: `p02-executor-architecture-20260828`
- Input baseline: `533796e4173c0128e452c22cc60606c32be3fe81`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## USR-016 Addendum

The project-authored corpus is not an external admission and does not pass
through quarantine. Its tracked generator specification, schemas, generated
artifacts, lineage manifest, and freeze record are Apache-2.0 project paths.
The validator must reproduce all outputs byte for byte, bind each label to the
pre-engine specification, keep split families disjoint, and reject any claim
that the corpus is independently sourced or representative.

P02 is an evidence and data-control phase, not a language implementation
phase. It adds no crate or runtime dependency. Structured manifests, schemas,
validators, source dossiers, immutable admitted inputs, and split/freeze
evidence are its only eligible product-tree outputs.

## Source State Machine

Every external payload starts outside the repository or under ignored
`data/quarantine/`. Quarantined bytes are unreachable from normal build,
test, runtime, linguistic, and evaluation paths. A source has one atomic
decision:

1. `QUARANTINED_CANDIDATE` while facts and five reviews are incomplete;
2. `REJECTED` with reason and removal evidence; or
3. `ADMITTED_AUTONOMOUS` after all required facts, reviews, executor
   verification, and an accepted source-decision ADR exist.

There is no partially admitted state. A metadata-only license claim cannot
promote payload bytes. Each admitted source receives a stable source ID and a
dossier under `docs/evidence/sources/<source-id>/`; source payloads and every
derivative retain that ID. The dossier records exact acquisition, extraction,
normalization, split, compile, and selective-removal recipes even when P03
will execute the later transforms.

The source manifest must separate source software, language content, database
rights, annotation rights, and generated outputs. It records actual
rightsholders, complete license hashes, immutable revision and artifact
identity, exact path scope, obligations, derivative licensing, redistribution,
privacy limits, and bounded intended uses. Merged entries carry every
contributing provenance rather than one preferred origin.

## Evaluation Freeze

P02 freezes taxonomy before data:

1. release-supported intents, domains, operations, slots, entities, graph
   shapes, outcomes, ambiguity classes, noise strata, and denied families;
2. sensitive-operation and confirmation classes, including unlock, access
   opening, alarm disablement, and safety-affecting control;
3. contradiction and stale-state acceptance boundaries;
4. immutable quota and weighting policy.

Case selection then uses stable upstream record IDs and an anti-leakage group
appropriate to each source. A versioned deterministic assignment maps complete
groups, never individual near-duplicate utterances, to train, development,
held-out, performance, or zero-false-plan suites. Source and utterance-family
groups cannot cross the held-out boundary.

The held-out package is hash-addressed and access-segregated. Its tracked
control manifest exposes identities, coverage, quotas, licenses, generator
lineage, and digests needed for audit, but post-freeze implementation work
must not read held-out text or case-level outcomes. The release-gate runner
loads the sealed package and emits only aggregate authorized results.
Repository tools must neither print held-out records nor place them in logs,
fixtures, snapshots, compiler inputs, or ordinary test output.

The performance corpus is a distinct project-authored case set. It is selected from
the frozen coverage taxonomy and source pool without reading or copying
held-out text. Every item has a pre-engine exact outcome. One item
belongs to at most one stratum on each mandatory dimension; a single item may
simultaneously represent one stratum in different dimensions.

The five zero-false-plan suites are separate manifests. Their expected outcome
is always a typed non-plan outcome. One canonical semantic identity cannot
satisfy two classes in the same suite, and no empty suite or class is valid.

## Validation Boundary

P02 should use the already admitted standard-library Ruby/Psych validation
surface unless a new dependency is independently admitted. Planned real
artifacts include a versioned source-manifest schema, evaluation-manifest
schema, deterministic validator, mutation runner, source dossiers, freeze
digest, and P02 report. Placeholder schemas, empty data directories, and
unconsumed modules are prohibited.

The validator must prove:

- strict structured parsing, bounded sizes and nesting, unique IDs, stable
  ordering, and exact field domains;
- source bytes, sizes, revisions, path scopes, license bytes, and reviewer
  identities;
- quarantine/build isolation and no unadmitted input reachability;
- per-case generator-oracle lineage, PT-BR and Home Assistant scope, split
  grouping, semantic uniqueness, quota and weighting immutability;
- 3,715 global scored cases, 237 cases per supported scored stratum, 237 items
  per supported performance stratum, and all nonempty suite classes;
- held-out access and output restrictions, corpus removal, defect invalidation,
  and reviewed refreeze;
- identical manifests and split outputs from clean roots with fixed tools,
  inputs, arguments, locale, timezone, and path normalization.

## Alternatives And Counterexample

Committing all held-out text beside ordinary development tests is simple but
cannot support the post-freeze access prohibition. Encrypting it with a key in
the same repository is equivalent to plaintext. The boundary must be enforced
by artifact separation, access procedure, command behavior, and audit evidence,
not obscurity.

Evidence inspected: `AGENTS.md`, `docs/clean-room/SOURCE-POLICY.md`,
`docs/clean-room/MATERIALS.yaml`,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`, ADRs 0001, 0002, 0005, 0006,
and 0008, and P01 architecture evidence. Commands used were read-only `find`,
`grep`, `sed`, Ruby 2.6 inventory, and Git inspection.
