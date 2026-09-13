# P04 Pre-phase Requirements Analysis

- Role: `executor-requirements-synthesis`
- Analysis instance: `p04-executor-requirements-20260828`
- Input baseline: `c2685e4ca931ce631f329aa36f652ec4c436b49d`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Scope

P04 owns the 13 Unicode requirements and the P04 portions of the shared text,
word-count, language-boundary, and security rows. It must add a real
`lang-ptbr` component that preserves the immutable `RequestText`, performs one
explicit canonical normalization, maps normalized spans back to original
half-open UTF-8 byte spans, and applies bounded fail-closed input policy.

P04 must:

- preserve original request bytes and never remove accents globally;
- use Unicode 17.0.0 NFC without compatibility folding or case folding;
- make normalization idempotent and map every accepted normalized span
  reversibly to an original span;
- reject non-UTF-8 boundaries and normalization-unit interior boundaries;
- admit combining marks through NFC while rejecting controls and the explicit
  zero-width/default-ignorable security set;
- preserve confusable code points as distinct values;
- enforce independent byte, scalar, grapheme, and Unicode-word limits;
- freeze a versioned Unicode word-count algorithm for later benchmarks;
- validate normalization and boundary behavior against immutable official
  Unicode 17.0.0 conformance files.

P04 does not define PT-BR vocabulary, tokenization rules, morphology, syntax,
semantics, ranking, Home Assistant policy, or execution. Unicode conformance
data is technical standards evidence, not linguistic gold or training data.

## Source Selection

The first source portfolio is selected:

- Unicode Character Database 17.0.0 archive, SHA-256
  `2066d1909b2ea93916ce092da1c0ee4808ea3ef8407c94b4f14f5b7eb263d28e`;
- `unicode-normalization` 0.1.25, archive SHA-256
  `5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8`;
- `unicode-segmentation` 1.13.3, archive SHA-256
  `c6f5d3c3b1bf09027a88a6bc961fc00497d651009560b5463668dc81b0fa87a8`;
- the exact `tinyvec` 1.12.0 and `tinyvec_macros` 0.1.1 runtime closure.

The two Unicode crates and official conformance files all identify Unicode
17.0.0. The selected software licenses are Apache-2.0 from dual or triple
permissive expressions. The official data is covered by Unicode License V3.
No selected component has a runtime network client, process launcher, build
script, or ambient configuration dependency.

## Minimum Acceptance

A convergence pass is one integrated Unicode source, normalization, mapping,
and limit approach that is selected and then frozen, dispositioned, or
rejected. Pass 1 selects the portfolio and structure above. No more than three
pre-candidate passes and three frozen candidates are allowed.

The first P04 candidate is frozen immediately when:

1. every P04 Unicode row has a positive, boundary, and relevant negative test;
2. the complete admitted Unicode 17 normalization, grapheme, and word-boundary
   conformance inputs pass;
3. normalized/original span round trips pass for accepted boundaries and
   invalid UTF-8 or normalization-unit boundaries fail closed;
4. exact and one-over scalar, grapheme, token, and inherited byte limits pass;
5. control, zero-width, combining-mark, accent, and confusable policies pass;
6. the dependency, license, distribution, P01, P02, and P03 inherited gates
   pass with no P0-P2 implementation finding.

Rounds two and three may only repair reproduced blockers. Optional folding,
transliteration, locale tailoring, broader language behavior, or performance
refinement is deferred.

## Findings

- **P1:** eligible independent pre-phase instances are unavailable. These
  executor syntheses do not satisfy `REV-PRE-001` through `REV-PRE-003`.
- **P1:** mapping individual normalized scalar values is not reversible when
  NFC composes or reorders combining sequences; accepted map boundaries must
  be canonical grapheme-unit boundaries.
- **P1:** compatibility normalization would silently alias confusables and
  symbols, so only NFC is eligible.
- **P2:** a scalar-only input limit does not bound grapheme or word-boundary
  work independently; all four counters must be checked.

## Counterexample

Normalizing `a` plus a combining acute accent to a precomposed scalar and then
copying byte offsets would point into unrelated original bytes. A valid
implementation maps the whole normalized grapheme unit to the original
decomposed byte range and rejects an attempted boundary inside that unit.

Evidence inspected: `AGENTS.md`, the P04 and shared requirement rows, ADRs
0003, 0005, 0007, and 0008, source policy, dependency ledger, `RequestText`,
official crates.io metadata and archives, and the official Unicode 17.0.0 UCD
archive. Repository inspection used read-only `find`, `grep`, `sed`, Ruby,
archive listing, hashing, and Git commands.
