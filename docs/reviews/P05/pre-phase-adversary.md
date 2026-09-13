# P05 Pre-phase Adversarial Analysis

- Role: `executor-adversarial-synthesis`
- Analysis instance: `p05-executor-adversary-20260828`
- Input baseline: `1685e44dd1f4eb60aeca016c705dc0b22c7a74c4`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Threat Model

| Severity | Hypothesis | Required control |
| --- | --- | --- |
| P0 | A token cites normalized offsets as original request bytes. | Store both source-bound span types and verify every normalized-to-original round trip. |
| P0 | A contraction part claims bytes that do not exist in the surface. | Project logical parts to the full surface span and label the projection explicitly. |
| P1 | An unproved productive rule silently splits an entity name or command. | Restrict linguistic decomposition to exact admitted forms and preserve all other forms as unknown. |
| P1 | Exception matching consumes a prefix inside a longer connected form. | Compute the complete connector run first and require an exact candidate to consume it. |
| P1 | A short exception wins before a longer exception. | Use deterministic longest-first exact matching. |
| P1 | Internal punctuation destroys `i.e.`, `km/h`, or another admitted exact form. | Apply exact admitted merges before default word boundaries. |
| P1 | Punctuation adjacent to an exception is swallowed into its span. | Require exact end boundaries and emit trailing punctuation independently. |
| P1 | P05 emits more tokens than P04's approximate word count predicted. | Enforce the token limit on final P05 output before returning a value. |
| P1 | Logical parts or debug output disclose request text. | Keep part identities as closed source-derived IDs and redact all text from `Debug`. |
| P2 | Reordering source tables changes output. | Sort or encode fixed longest-match precedence and test table permutation. |
| P2 | A repeated tokenization changes classes or parts. | Require a per-token rebased fixed point for every output class. |
| P2 | Public examples are misreported as broad PT-BR accuracy evidence. | Classify them as narrow conformance regressions only. |

## Required Tests

Tests cover exact source examples for Unicode punctuation, CLDR decimal comma,
CLDR `HH:mm`, `quilômetro`, `km/h`, contractions, enclisis, mesoclisis,
abbreviations, and multiunits;
original/normalized span slices; decomposed-part projection; longest-match and
case sensitivity; leading, trailing, repeated, and adjacent punctuation;
unsupported hyphen, slash, apostrophe, URL-like, email-like, and mixed-script
forms; empty and whitespace-only input; exact and one-over token limits;
repetition, rule-table permutation, and per-token fixed points.

Source tests verify exact byte count, Git blob where applicable, and SHA-256
for every retained source and license, reject source mutation, and prove each
runtime literal or bounded pattern is present in its declared source.

Convergence pass 1 was rejected on the prefix, semantic-scope, derivative
notice, and premature-promotion hypotheses. Pass 2 removes spaCy, narrows
numeric and punctuation semantics, adds the Apache changed-file notice, and
keeps every material candidate-only until five independent reviews pass.

## Failure Policy

Malformed input remains rejected by P04 before P05. P05 returns no partial
tokenization on span, invariant, or limit failure. Unsupported forms are not
errors, but they remain intact and carry `Unknown` plus
`UnsupportedPreserve`; they never inherit a guessed class.

No fourth convergence pass or candidate is allowed. Routine source-download or
command retries do not consume a pass; replacing the source portfolio,
representation, or boundary precedence does.

## Counterexample

Given `km/h,`, a scanner that consumes non-whitespace first produces one
unsupported token and loses the admitted multiunit. A scanner that splits
punctuation first produces `km`, `/`, `h`, `,` and also loses it. The exact
`km/h` merge must win, stop at its boundary, and leave the comma as a separate
punctuation token.

Evidence inspected: `AGENTS.md`, source policy, P05 and shared requirements,
P04 span and limit behavior, Unicode 17 data, exact UD and CLDR sources, and
existing gate patterns.
