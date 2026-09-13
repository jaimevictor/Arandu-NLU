# P02 Pre-phase Adversarial Analysis

- Role: `executor-adversarial-synthesis`
- Analysis instance: `p02-executor-adversary-20260828`
- Input baseline: `533796e4173c0128e452c22cc60606c32be3fe81`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## USR-016 Addendum

Synthetic origin is now expected only for the exact project-authored corpus.
The main replacement risks are circular labels, implementation-shaped
templates, duplicate expansion, post-freeze augmentation, and inflated
external claims. Mitigations are a pre-engine semantic generator
specification, deterministic lineage, family-disjoint splits, canonical text
and semantic duplicate rejection, immutable freeze digests, and an
internal-conformance-only claim check.

The candidate gate must close these hypotheses:

| Severity | Hypothesis | Required mitigation |
| --- | --- | --- |
| P0 | A repository license covers code or an importer but not the underlying language content. | Establish content rightsholders, path scope, database/annotation rights, and complete license bytes independently. |
| P0 | Project output establishes or repairs expected semantics. | Require a versioned generator specification fixed before NLU implementation and reject every NLU-derived or post-hoc label. |
| P0 | Held-out text or case-level results leak into implementation context after freeze. | Segregate the package, deny ordinary reads and logs, audit accesses, and expose only authorized aggregate results. |
| P0 | Template expansions, spelling variants, or duplicate semantics inflate the 3,715 or 237-case floors. | Enforce unique upstream and canonical semantic identities and group near-duplicates before splitting. |
| P0 | The supported denominator is narrowed or relabeled after seeing source availability or model results. | Freeze support and taxonomy first; treat any later expansion or identity change as invalidating and requiring refreeze. |
| P1 | A mutable tag, submodule, release asset, large-file pointer, or generated download differs from reviewed bytes. | Resolve immutable commits and exact artifacts, hash every retained byte, and replay acquisition in a clean root. |
| P1 | Source and held-out splits share a document, template family, speaker, semantic family, or upstream record. | Assign complete anti-leakage groups and test every cross-split group intersection. |
| P1 | A permissive wrapper conceals share-alike, attribution, privacy, or no-redistribution obligations in a derivative. | Track license and obligations per source and derivative; isolate compatible share-alike outputs. |
| P1 | Language outside the exact project-authored exception is model-generated, translated, synthetic, or unprovenanced. | Require explicit `PROJECT_AUTHORED_SYNTHETIC` lineage or eligible external admission and reject every other affected record. |
| P1 | Archive paths, symlinks, decompression ratios, malformed encodings, or duplicate filenames compromise quarantine inspection. | Use a bounded extractor, canonical path checks, byte limits, encoding checks, and no executable payloads. |
| P1 | Residential utterances or personal identifiers are admitted from a public dump without valid rights and privacy review. | Review privacy and collection authority; reject or deterministically remove affected records before admission. |
| P1 | Multi-source merging erases conflicting provenance or lets one accepted source launder a rejected contribution. | Preserve all per-entry source IDs and make any rejected contribution remove the merged entry or affected derivative. |
| P1 | A frequency list ranks language through an opaque corpus with incompatible rights. | Admit corpus and derived-frequency rights together or use the measured corpus-free fallback. |
| P2 | ASR-noise acquisition becomes speculative scope and introduces personal speech or restrictive data. | Record a need decision first and keep NLU text-input scope explicit. |

## Required Adversarial Checks

Mutation tests delete or alter every source-manifest field, review identity,
license hash, artifact hash, path scope, rightsholder, obligation, intended
use, split group, oracle source, taxonomy, quota, weighting, case identity,
and freeze digest. They substitute mutable revisions, restricted licenses,
wrapper-only licenses, rejected owners, unadmitted source IDs, project-output
oracles, AI origins, duplicate identities, empty classes, underfilled strata,
and post-freeze changes.

Acquisition tests use hash mismatch, size mismatch, path traversal, absolute
paths, case-colliding filenames, symlink escape, nested archives, oversized
expansion, malformed UTF-8, and unexpected executables. Split tests construct
shared document, family, speaker, source, and semantic groups across partitions.
Removal tests delete one source and require every direct, merged, normalized,
compiled, evaluation, and performance contribution to disappear.

Held-out tests place canaries in text and expected outcomes and require their
absence from normal builds, tests, logs, diagnostics, source scans, snapshots,
and implementation-visible reports. A digest-only manifest is insufficient:
the release runner must also bind each aggregate result to the frozen package,
runner, taxonomy, and quota identities.

## Counterexamples

An upstream CC-BY repository can still be unusable when its license applies
only to annotations while sentence copyright remains elsewhere. A deterministic
split can still leak when it hashes individual sentences rather than source
families. A source can contain 3,715 strings while providing far fewer than
3,715 independent semantic cases.

Evidence inspected: `AGENTS.md`, `docs/clean-room/SOURCE-POLICY.md`,
`docs/clean-room/MATERIALS.yaml`,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`, ADRs 0001, 0002, 0005, 0006,
and 0008, and P01 adversarial evidence. Commands used were read-only `find`,
`grep`, `sed`, Ruby 2.6 inventory, and Git inspection.
