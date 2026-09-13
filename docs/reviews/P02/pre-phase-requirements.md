# P02 Pre-phase Requirements Analysis

- Role: `executor-requirements-synthesis`
- Analysis instance: `p02-executor-requirements-20260828`
- Input baseline: `533796e4173c0128e452c22cc60606c32be3fe81`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## USR-016 Addendum

The original analysis correctly identified that no eligible external oracle
could meet minimum acceptance. The later explicit user decision `USR-016`
supersedes that origin requirement for P02 and permits an Apache-2.0
project-authored synthetic conformance corpus. The retained minimum is 3,715
distinct scored cases, 237 cases per supported stratum, five nonempty
fail-closed suites, deterministic family-disjoint splits, pre-engine expected
semantics, and zero NLU-derived labels. The resulting metric is internal
conformance, not independent linguistic accuracy or Sophia equivalence.

The phase-owner inventory expands to 440 applicable rows when `All` and phase
ranges are included. Its P02-specific surface includes 54 data-admission rows,
9 source goals, 128 direct or shared quality/performance rows, `USR-005`, and
the P02 slices of linguistic provenance, evaluation isolation, deterministic
behavior, safety classification, licensing, validation, and review controls.

P02 must deliver these bounded groups:

- discovery dispositions for lexicon/morphology, contextual POS evaluation,
  PT-BR intent and multi-intent evaluation, ASR-noise need, and an independent
  frequency source or measured corpus-free substitute;
- complete source dossiers with immutable bytes, owner and rightsholder
  evidence, full license bytes, rights and obligations, intended use,
  transformations, redistribution, removal, and five distinct source reviews;
- quarantine isolation and fail-closed promotion or rejection decisions;
- a frozen release-support denominator and the risk, contradiction,
  ambiguity, stale-state, negative, graph, slot, entity, and outcome
  taxonomies needed to measure it;
- at least 3,715 distinct scored PT-BR Home Assistant cases with independent
  oracle lineage and the nine frozen coverage dimensions;
- at least 237 distinct cases in every declared supported scored stratum, with
  frozen quotas and weighting;
- separate nonempty safety-sensitive, contradiction, ambiguity, stale-state,
  and explicit-negative suite manifests with every frozen class covered;
- a separate representative performance corpus, derived from coverage without
  exposing held-out text, with at least 237 distinct items in every supported
  performance stratum and one membership per dimension;
- deterministic validators and mutation tests for identity, duplicates,
  provenance, licenses, quotas, split leakage, freeze chronology, held-out
  access, refreeze, and source removal.

Shared P02/P03 manifest rows establish the P02 contract and source facts; P03
owns import-pipeline enforcement. P02 does not implement morphology, parsing,
intent recognition, Home Assistant execution, runtime transport, or packaging.
It may prototype a corpus-free fallback only to establish that an essential
missing source does not block a later deterministic implementation.

## Minimum Acceptance

P02 has at most three substantive frozen candidates. Candidate round one is
frozen as soon as all phase-close requirements and checks pass. Admission
requires all five source-review roles per admitted source. Phase close requires
requirements, correctness, test-oracle, risk, reproducibility, and linguistics
reviews to pass the same immutable candidate, no P0 through P2 finding to
remain, and the evidence checkpoint to validate. Unused rounds are not used
for optional source expansion or dossier refinement.

The minimum source portfolio is the smallest independently admitted set that
supports every frozen release claim and required evaluation class. A source is
not admitted merely because it is useful. Missing optional coverage is
recorded as unsupported; a missing mandatory oracle or quota is a blocker.

## Preconditions And Findings

- **P0:** freeze the exact declared release-support denominator before case
  selection. Later expansion invalidates affected coverage and requires a new
  independently reviewed freeze.
- **RESOLVED BY USR-016:** expected outcomes may come from the versioned
  project-authored generator specification when fixed before NLU
  implementation. Project NLU output still cannot establish or repair labels.
- **P0:** define an access boundary that prevents post-freeze accuracy work
  from inspecting held-out text or case-level results.
- **P1:** prove that eligible sources can supply 3,715 distinct semantic cases
  and every 237-case supported-stratum quota without template or identity
  duplication.
- **P1:** eligible independent pre-phase analysis instances are not currently
  available. This executor synthesis permits investigation but does not satisfy
  `REV-PRE-001` through `REV-PRE-003`.
- **P1:** define the exact P02 manifest schemas, freeze digest, candidate gate,
  and P02-to-P03 checkpoint validator before candidate freeze.
- **P2:** make and evidence the ASR-noise need decision; do not acquire an
  acoustic or transcript corpus speculatively.

## Counterexample

Expanding one upstream sentence template into thousands of surface strings
does not by itself create thousands of distinct semantic cases. Counting those
strings without independent oracle identities, anti-leakage grouping, and
canonical semantic uniqueness would satisfy a file-count target while
invalidating the quality contract.

Evidence inspected: `AGENTS.md`, `docs/clean-room/USER-DECISIONS.md`,
`docs/clean-room/SOURCE-POLICY.md`,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`, ADRs 0001, 0002, 0005, 0006,
and 0008, the P01 pre-phase reports, and both phase-state files. Commands used
were read-only `find`, `grep`, `sed`, Ruby 2.6 requirement inventory, and Git
inspection.
