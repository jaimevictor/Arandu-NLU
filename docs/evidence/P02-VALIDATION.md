# P02 Corpus Validation Evidence

- Phase: `P02`
- Candidate: `24af7cef7d949ae8b796e91f6c3910805c28ac1e`
- Candidate tree: `0a0dfcbe867ed2f5efb9f7b158164f5d2ff3717f`
- Candidate round: 1 of 3
- Validation time: `2026-08-28T21:50:38Z`
- Reproduction time: `2026-08-28T21:54:20Z`
- Corpus: `project-authored-synthetic-ptbr-v1` version `1.0.0`
- Authorization: `USR-016`
- Result: `PASS`

## Scope

This evidence covers an Apache-2.0 project-authored PT-BR conformance corpus.
Its expected semantics are fixed by
`data/project-authored/p02-v1/specification.yaml` before NLU implementation.
The corpus is not independently sourced, representative natural-language
data, an external accuracy oracle, or evidence of Sophia equivalence.

No rejected external payload was admitted. The prior external-source search,
license dispositions, and corpus-free fallback measurement remain recorded in
`docs/evidence/P02-SOURCE-DISCOVERY.md`,
`docs/evidence/P02-CORPUS-FREE-FALLBACK.md`, and the four source rejection
reports.

## Executed Gate

The following commands completed successfully:

```text
ruby -c tools/generate-p02-corpus.rb
ruby -c tools/validate-p02.rb
ruby -c tools/test-validate-p02.rb
ruby -c tools/generate-p02-corpus
ruby -c tools/validate-p02
ruby -c tools/test-validate-p02
tools/test-validate-p02
tools/generate-p02-corpus --check
tools/validate-p02
```

`tools/test-validate-p02` returned `P02_VALIDATION_TESTS_PASS`.
`tools/generate-p02-corpus --check` returned
`P02_CORPUS_GENERATION_CHECK_PASS`. `tools/validate-p02` returned
`P02_VALIDATION_PASS`.

The inherited repository gate `tools/validate-p01` returned `P01_GATE_PASS`.
Its four mutation tests returned `P01_GATE_TESTS_PASS`, covering package-file
hash corruption, distribution path and prefix matching, source-boundary
rejection, and lockfile parsing.

The test runner passed 12 tests. It reproduced the complete generated path set
twice in independent temporary directories and exercised duplicate semantic
identity, duplicate JSON key, underfilled corpus, NLU-derived oracle,
cross-split family, suite-plan, corrupt POS byte span, changed language-data
license, external-accuracy claim, and invalid UTF-8 rejection.

## Frozen Corpus

The generated corpus contains:

| Artifact class | Records |
| --- | ---: |
| Train semantic cases | 960 |
| Development semantic cases | 960 |
| Held-out scored cases | 4,800 |
| Performance cases | 4,800 |
| Contextual POS cases | 241 |
| Lexicon analyses | 33 |
| Morphology cases | 29 |
| Safety-sensitive suite | 5 |
| Contradiction suite | 5 |
| Ambiguity suite | 5 |
| Stale-state suite | 5 |
| Explicit-negative suite | 7 |

The held-out and performance sets each contain 240 cases for every one of the
20 pinned Home Assistant intent families. The validator enforces at least
3,715 held-out cases and at least 237 distinct cases in every declared source,
family, intent, domain, slot-kind, graph-shape, outcome, ambiguity, and noise
stratum.

Train, development, held-out, and performance records are pairwise unique by
case ID, generator record ID, canonical semantic identity, and utterance.
Families do not cross splits. The manifest records all mandatory dimension
counts, target cardinality, quotas, unweighted evaluation, artifact byte
sizes, record counts, and SHA-256 values.

## Contract And Oracle

The semantic taxonomy is pinned to Home Assistant Core commit
`759e4658f40b3ccb671d418b8a0ed95224bf4561`. The public contract file
`homeassistant/helpers/intent.py` has recorded SHA-256
`8a62d1ab08d66a60a6c397bbb4d0b0ef12770c924ef8fd4ecffd690143703f9f`.
All 20 built-in intent families from that contract are represented.

Every semantic and suite record carries source, corpus version, generator,
Apache-2.0 license, `pt-BR` locale, utterance hash, and canonical semantic
identity. The validator requires oracle origin
`pre_engine_generator_specification`, rejects any self-derived oracle, and
requires the manifest claim scope to remain `internal_conformance_only`.

The five fail-closed suites cover 27 distinct classes. Every expected result is
clarification or abstention, and no canonical semantic identity, utterance,
case ID, or generator record ID is reused across suites.

## Reproduction And Change Control

The manifest binds the specification and generator hashes and every generated
artifact. Regeneration occurs in a fresh temporary root and compares every
byte to the tracked corpus. A corpus or oracle defect invalidates affected
results and requires a new versioned specification, generated corpus, freeze,
and candidate; in-place repair of version `1.0.0` is not an accepted refreeze.

Post-freeze implementation must treat held-out text and case-level outcomes as
sealed evaluation input. P03 may import the package through deterministic
pipeline controls; normal tuning may use only train and development records.
P15 owns aggregate conformance execution and must not relabel these results as
independent accuracy.

## Review Direction

The user directed the executor to skip the final P02 review after this
successful run and move on. No independent PASS report is fabricated. The
waiver covers the unavailable independent P02 pre-phase instances and the
post-phase requirements, correctness, test-oracle, risk, reproducibility, and
linguistics reviews for this P02 closeout only.

## Non-applicable Legacy Check

`tools/test-validate-governance` was attempted and did not pass. Its P00-only
clean-subject setup stopped before mutation execution because it rejects the
pre-existing P01 vendored binary
`vendor/unicode-ident-1.0.24/tests/fst/xid_continue.fst` for containing NUL
bytes. That launcher validates the P00 candidate shape and is not a P02 gate;
the current distribution and source checks are owned by `tools/validate-p01`.
No P02 pass claim relies on the failed legacy command.

## Exact-commit Reproduction

A local `git clone --no-hardlinks` created the clean root
`/private/tmp/nlu-p02-repro.whQZFl`. It checked out candidate
`24af7cef7d949ae8b796e91f6c3910805c28ac1e` with tree
`0a0dfcbe867ed2f5efb9f7b158164f5d2ff3717f` and an empty worktree status.
Representative generator, validator, and held-out files had different inode
identities from the candidate worktree.

Inside that clone, `tools/generate-p02-corpus --check`,
`tools/validate-p02`, and `tools/test-validate-p02` returned their exact PASS
sentinels again. This closeout reproduction used candidate-controlled checks;
it establishes deterministic replay of the frozen package, not independent
review or an external linguistic oracle.
