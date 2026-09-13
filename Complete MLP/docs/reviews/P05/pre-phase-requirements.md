# P05 Pre-phase Requirements Analysis

- Role: `executor-requirements-synthesis`
- Analysis instance: `p05-executor-requirements-20260828`
- Input baseline: `1685e44dd1f4eb60aeca016c705dc0b22c7a74c4`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Scope

P05 owns the 13 tokenization rows and the P05 portions of shared language-rule,
unknown-fact, determinism, resource-bound, and test requirements. It extends
the real `lang-ptbr` component without changing P04 normalization or original
request bytes.

P05 must:

- give every surface token checked normalized and original half-open UTF-8 byte
  spans bound to one `NormalizedText`;
- record one admitted rule and one boundary operation for every token;
- expose source-supported decomposition parts without inventing byte offsets
  for characters absent from the surface form;
- cover punctuation and numeric boundaries from admitted Unicode 17 and
  Portuguese documentation;
- cover exact time, unit, contraction, clitic, abbreviation, and multiunit
  forms from admitted public sources;
- preserve every unproved form as one explicit unknown token rather than
  guessing a linguistic decomposition;
- enforce the existing 4,096-token limit on actual P05 output;
- produce stable ordered output and a per-token fixed point.

P05 does not interpret numeric values, validate clock ranges, assign lemmas or
parts of speech, generalize productive contraction or clitic paradigms, or
perform syntax, intent, entity, policy, or execution work.

## Source Selection

Convergence pass 1 selected Unicode 17, UD Portuguese documentation, and spaCy
Portuguese exceptions. It was rejected before candidate freeze after
adversarial source review found that spaCy history touched rejected Bosque
material, exception membership did not prove the assigned semantic classes,
and generic punctuation and numeric classes exceeded the admitted evidence.
All spaCy retained bytes, rules, tests, and distribution claims are removed.

Convergence pass 2 selects:

1. Unicode 17.0.0 default word boundaries plus exact ASCII code points whose
   `UnicodeData.txt` general category begins with `P`;
2. Universal Dependencies documentation commit
   `bdd95cf20660e21a3f60bb84e2c93d1f3efcd74b`, tree
   `135fab3f7da3052c4951568a416dca7b6a2bdd87`, only for exact Portuguese
   contraction, mesoclisis, enclisis, clitic-pronoun, and abbreviation
   examples;
3. CLDR release 48 commit `acd6d88ae493633240e19a87a721076a8a75c310`,
   tree `bafae8fc919257506cb84327781ce4912b9b0c0b`, for exact `latn` digits,
   Portuguese decimal comma and `HH:mm`, literal `quilômetro`, and literal
   `km/h`.

No rejected treebank, spaCy source, model output, sentence data, or
closed-engine behavior contributes a pass-2 rule.

## Minimum Acceptance

A convergence pass is one selected source portfolio plus one integrated token
representation and boundary algorithm. At most three pre-candidate passes and
three frozen candidates are allowed.

The first P05 candidate is frozen immediately when:

1. all 13 P05 rows have positive, boundary, and relevant negative tests;
2. every emitted token and decomposition maps to its exact surface source
   bytes and every decision names an admitted rule;
3. public-source regressions cover each required token class and bind every
   finite allowlist or bounded pattern to exact retained source rows;
4. unsupported forms remain explicit unknowns;
5. repetition, input-order permutation, per-token fixed-point, exact-limit,
   and one-over-limit tests pass;
6. inherited P01, P02, and P04 gates pass with no reproduced P0-P2 blocker.

Rounds two and three may only repair reproduced blockers. Broader dictionaries,
productive morphological rules, heuristic URL/email handling, optional
refinement, and performance tuning are deferred.

## Findings

- **P1:** eligible independent pre-phase instances are unavailable. These
  executor syntheses do not satisfy independent review requirements.
- **P1:** logical contraction or clitic parts cannot receive fabricated
  disjoint source spans; each part must project to the complete surface span
  and declare that projection.
- **P1:** Unicode boundaries alone do not justify Portuguese decomposition;
  only exact admitted examples may decompose in P05.
- **P2:** treating every unknown word as linguistically supported would violate
  the unknown-fact requirement; ordinary unproved words need an explicit
  unknown classification.

## Counterexample

Splitting `do` into byte spans for `de` and `o` would claim that an `e` exists
in the request. The surface token must retain the exact span for `do`; its
source-supported logical parts may both project to that span while recording
that they are analyses rather than copied substrings.

Evidence inspected: `AGENTS.md`, P05 and shared requirement rows, ADRs 0001,
0006, 0008, and 0010, P04 span APIs and conformance data, exact UD Portuguese
documentation, Unicode 17 data, and exact CLDR 48 Portuguese and numbering
system data.
