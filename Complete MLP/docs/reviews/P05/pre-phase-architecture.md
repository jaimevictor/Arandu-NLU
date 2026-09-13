# P05 Pre-phase Architecture Analysis

- Role: `executor-architecture-synthesis`
- Analysis instance: `p05-executor-architecture-20260828`
- Input baseline: `1685e44dd1f4eb60aeca016c705dc0b22c7a74c4`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Selected Structure

Extend `crates/lang-ptbr` with one tokenizer module and no new runtime
dependency. `NormalizedText::tokenize` returns an immutable ordered
`Tokenization`. Each `Token` contains:

- one source-bound normalized span;
- the corresponding source-bound original `Utf8Span`;
- a closed token class;
- a closed boundary operation;
- one stable admitted rule identifier;
- zero or more logical parts, each with an explicit full-surface projection
  and source rule.

Spans remain private checked types. Debug output reports classes, rule IDs,
counts, and offsets but never request text or derived part text.

## Boundary Algorithm

The tokenizer scans normalized text from left to right:

1. skip Unicode whitespace without emitting a token;
2. find the complete connected run at the current boundary;
3. prefer a longest exact admitted Portuguese exception only when the rest of
   that complete run is admitted terminal punctuation;
4. apply exact admitted contraction or clitic decomposition;
5. apply only the bounded CLDR decimal and `HH:mm` patterns;
6. otherwise consume one Unicode 17 default word-bound segment;
7. emit only the exact ASCII `P` general-category allowlist as punctuation;
8. preserve any remaining connected unsupported form as one unknown token.

Exact exception matching is case-sensitive because the source enumerates
case variants. Longest-match order is stable and fixed in source. No hash-map
iteration, locale, clock, environment, randomness, network, or filesystem
state affects output.

## Classes And Operations

The minimum closed classes are `Number`, `Punctuation`, `Time`, `Unit`,
`Contraction`, `Clitic`, `Abbreviation`, `Multiunit`, and `Unknown`.

Operations are `UnicodeBoundary`, `PunctuationBoundary`, `ExactPreserve`,
`ExactMerge`, `LogicalDecomposition`, and `UnsupportedPreserve`. A merge means
that an admitted exact form such as `i.e.`, `12:30`, or `km/h` remains one
surface token despite internal Unicode boundaries. A logical decomposition
does not mutate surface bytes.

The pass-2 rule namespace distinguishes:

- Unicode 17 default word boundaries;
- Unicode 17 exact ASCII punctuation code points;
- UD Portuguese documentation at the admitted commit;
- CLDR 48 Portuguese literal and bounded-pattern evidence.

## Idempotence And Limits

Tokenizing the normalized slice of any emitted token must produce exactly one
token with the same class, operation, rule, and logical parts after rebasing
offsets. This per-token fixed point is the P05 idempotence contract.

Actual P05 output is counted independently of P04's benchmark word count.
Exactly 4,096 tokens are accepted and a 4,097th token returns the existing
typed token-limit error without a partial result.

## Source And Distribution

Retain exact source bytes and complete license texts under versioned P05 data
paths. The source files are evidence and deterministic rule inputs, not
training data or an accuracy corpus. Record immutable commit/tree IDs, byte
counts, hashes, owner, rights, intended transformations, and selective-removal
paths in `docs/evidence/P05-SOURCES.yaml`. Materials remain
`QUARANTINED_CANDIDATE` until all five independent source reviews pass.

The implementation transcribes only explicit exact forms and examples.
Validation binds every transcribed rule to the retained source bytes. Removing
any source ID removes its rules and source-derived tests.

## Alternatives

1. Retain spaCy literals. Rejected by convergence pass 1 because provenance
   and semantic-class sufficiency did not satisfy source admission.
2. Import a rejected Portuguese treebank. Rejected because its underlying
   content rights remain unproved and sentence data is unnecessary.
3. Generalize every Portuguese contraction and clitic. Rejected because the
   selected sources do not provide a complete productive rule contract.
4. Assign synthetic byte spans to logical parts. Rejected because the bytes do
   not exist in the request.
5. Split every symbol mechanically. Rejected because exact abbreviations,
   times, and multiunits require admitted merges.

## Counterexample

Selecting contraction `do` before scanning the technical fixture
`do@FIXTURE_TECNICA` assigns a linguistic class to an unsupported identifier
prefix. The complete connector run must be known first. Conversely, `km/h,`
must recognize the exact `km/h` run and leave the comma independently
tokenized.

Evidence inspected: P05 requirements, P04 normalization and source-bound span
implementation, Unicode 17 data, exact UD and CLDR source bytes, workspace
dependencies, and distribution policy.
