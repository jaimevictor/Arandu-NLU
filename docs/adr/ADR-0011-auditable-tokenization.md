# ADR-0011: Auditable source-bounded tokenization

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-28
- Owners: P05-P09

## Context

P05 must preserve original byte evidence, explain every boundary, support
specific Portuguese forms only from admitted sources, and leave unsupported
facts unknown. Broad tokenizer libraries and productive handwritten language
rules would make source scope and later removal difficult to audit.

Convergence pass 1 used exact spaCy Portuguese exceptions. Independent
adversarial review rejected that portfolio because repository history touched
rejected material, exception membership did not prove the assigned semantic
classes, and the implementation inferred generic numeric and punctuation
classes. Pass 1 is not a candidate and contributes no runtime rule.

## Decision

`lang-ptbr` tokenizes P04 `NormalizedText` into ordered surface tokens. Every
token carries checked normalized and original half-open UTF-8 byte spans, a
closed class, a closed boundary operation, and one stable source rule ID.

Pass 2 uses three segregated source families:

- Unicode 17 default word boundaries and an exact allowlist of ASCII code
  points whose `UnicodeData.txt` general category begins with `P`;
- exact contraction, mesoclisis, enclisis, clitic-pronoun, and abbreviation
  evidence from the Apache-2.0 UD Portuguese documentation;
- CLDR 48 Portuguese decimal, time, unit, and multiunit evidence under
  Unicode-3.0.

The CLDR scope is deliberately narrow. Numeric tokens contain one or more
`latn` digits and optionally one decimal comma followed by one or more digits.
Time tokens have exactly the source pattern `HH:mm`; P05 does not validate
clock ranges. The only CLDR literals are `quilômetro` as a unit and `km/h` as a
multiunit expression. Grouping, signs, decimal periods, seconds, meridiem, and
other units remain unsupported.

Before selecting any exact rule, the scanner finds the complete connected run
formed from letters, digits, underscore, admitted ASCII punctuation, and the
explicitly unsupported plus sign. An exact
rule may win only when the remainder of the connected run is admitted terminal
punctuation. Thus `km/h,` keeps `km/h` and leaves the comma, while
the technical fixtures `do@FIXTURE_TECNICA`, `i.e./FIXTURE_TECNICA`, and
`i.e.\FIXTURE_TECNICA` remain complete unknown connected forms. This check
prevents an exact prefix from silently classifying a larger identifier.

Exact rules are case-sensitive, boundary-checked, longest-first, and
independent of source-table order. Logical contraction and clitic parts
project to the complete surface span; they never claim byte ranges for
characters absent from the request. Generic Unicode segments carry
`Unknown`; a boundary alone never proves a semantic class.

Final P05 output independently enforces the 4,096-token limit. P05 idempotence
means that tokenizing any emitted token's normalized surface again yields one
token with the same class, operation, source rule, and logical parts after
offset rebasing.

## Consequences

- Original evidence remains exact even when one surface has logical parts.
- Runtime has no new dependency, network, model, Python, locale, or filesystem
  behavior.
- Language coverage is intentionally narrow and can expand only through a
  separately admitted source and rule lineage.
- Inline derivative notices make the UD and CLDR transformations explicit.
- Removing one source ID removes its retained bytes, derived rules, rule IDs,
  source-derived tests, and ledger entries.
- The distribution carries Apache-2.0 and Unicode-3.0 notices at distinct path
  prefixes.

## Alternatives

1. Retain spaCy exact exceptions. Rejected by pass-1 source review and because
   CLDR directly supports the required time and unit classes.
2. Generalize examples into productive Portuguese rules. Rejected because the
   selected sources do not prove a complete grammar.
3. Treat every Unicode numeric or ASCII punctuation character as supported.
   Rejected because source boundaries do not prove semantic classes.
4. Split connector forms before exact matching. Rejected because it
   misclassifies exact prefixes inside larger unknown forms.
5. Assign synthetic byte spans to logical parts. Rejected because the missing
   bytes cannot be evidence.

## Rollback

Remove the tokenizer module, the two derivative rule files, retained P05
source paths, the P05 UnicodeData supplement, source-derived tests and
evidence, and this ADR index entry. P04 normalization and span behavior remain
unchanged.
