# P06 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04ae3-46ba-7e43-8ff9-4238d7c2fbaf`
- Input baseline: `901f2665027516c671d372ae1b3d227b49e0092d`
- Input tree: `88b244e990382a53ceebab27330b5ccce00bbad0`
- Mode: read-only repository analysis
- Independence: `INDEPENDENT_READ_ONLY_AGENT`
- Result: `ANALYSIS_COMPLETE`

## Boundary Finding

P06 must compile directly from separately pinned admission evidence and
verified source bytes. A generic P03 stage is not admission evidence: its
transform ID is self-described, and its current one-source envelope cannot
represent complete per-entry contribution lineage.

The existing source manifest also cannot be its own trust anchor. A candidate
could otherwise rewrite a lexical artifact and recompute every hash in the
same manifest. P06 requires an independent exact manifest identity in its
validator and compiler.

## Threat Model

| Severity | Hypothesis | Required control |
| --- | --- | --- |
| P0 | A coordinated source and manifest rewrite passes self-consistent hashes. | Pin the complete admitted manifest outside the supplied manifest and reject before output. |
| P0 | A forged intermediate stage bypasses source verification. | Expose no P06 compilation route from arbitrary P03 stages. |
| P0 | Locator, lineage, source license, or derivative license disappears. | Validate every field and every ordered transform hash on every entry. |
| P0 | Source removal leaves an entry, index posting, conflict member, inventory, or source-ID byte. | Rebuild from surviving whole entries and scan decoded and encoded outputs. |
| P1 | One conflict winner overwrites the other. | Map a surface to an ordered entry range and test both input orders. |
| P1 | Runtime callers mutate entries or indexes. | Private storage, shared-reference APIs, and no interior-mutable cache. |
| P1 | Malformed framing partially loads. | Reject bad magic/version/count/length, every truncation boundary, and trailing bytes. |
| P1 | Duplicate or unknown JSON fields change meaning. | Strict typed duplicate-key and closed-field parsing. |
| P1 | Bytes depend on input order, root path, locale, time, or entropy. | Canonical sort plus repeated clean-root and permutation builds. |
| P1 | A transform ID or source is caller-selectable. | Closed transform IDs and exact admission identity. |
| P1 | A future duplicate source ID names different source bytes. | Bind source ID to one exact manifest hash and retain separate source records. |
| P1 | Technical fixtures influence production language behavior. | Reject fixture markers in production compilation and compare production hashes with tests present. |
| P2 | Length or count claims allocate before bounds are checked. | Check exact and one-over package, entry, string, feature, and index limits before allocation. |
| P2 | Diagnostics disclose lexical text or truncate invalid UTF-8. | Emit typed structural errors only and test a private multibyte canary. |

## Required Counterexample Tests

The minimum negative and property suite must include:

1. remove one source row, recompute every caller-controlled count and hash,
   and prove the external manifest pin rejects the rewrite;
2. prove no API compiles a lexicon from a forged split or filtered stage;
3. delete or substitute each locator, lineage, source-license, and
   derivative-license field while recomputing outer package hashes;
4. reverse lineage order and substitute one inner input/output hash;
5. reverse all source rows and prove package and index equality;
6. retain both analyses for the existing repeated source surface under both
   source orders;
7. mutate magic, version, count, length, canonical JSON, identity, ordering,
   and trailing bytes and require one typed failure with no partial index;
8. remove the current sole source and prove zero entries, empty indexes and
   inventories, and no source-ID bytes;
9. use two opaque `FIXTURE_TECNICA` sources in a structural unit test and
   prove selective retention without admitting those fixtures;
10. reject removal of an absent source ID;
11. run the pure transform A-B-A and prove identical A output and unchanged
    input bytes;
12. exercise exact and one-over resource limits before allocation.

## Failure Policy

Compilation and removal write only to a new atomic destination. Any failure
returns no promoted artifact. Runtime decode constructs no `Lexicon` until the
entire package, sidecar manifest, every entry, and all indexes validate.

Unknown surfaces are not errors, but return `Unknown`. Conflicting source
facts are not resolved in P06; they return every entry as `Conflict`.

## Bounded Execution

Approach 1 is one direct pinned-source compiler, one contribution model, one
artifact/index format, and one removal contract. At most three convergence
passes and three candidate rounds are permitted. Candidate rounds 2 and 3 may
repair only reproduced P0-P2 blockers. The first passing candidate is frozen
without optional refinement.

## Counterexample

With a map from surface to one entry, forward insertion of the repeated source
surface retains one analysis and reverse insertion retains the other. This
both collapses observable ambiguity and makes behavior depend on source order.

Evidence inspected: `AGENTS.md`, source policy, boundary and user decisions,
P06 and inherited requirement rows, ADR-0009, the P02 source manifest and
lexicon, `nlu-data` manifest/pipeline/error limits, and P03/P05 validation
evidence.
