# P04 Pre-phase Adversarial Analysis

- Role: `executor-adversarial-synthesis`
- Analysis instance: `p04-executor-adversary-20260828`
- Input baseline: `c2685e4ca931ce631f329aa36f652ec4c436b49d`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Threat Model

| Severity | Hypothesis | Required control |
| --- | --- | --- |
| P0 | Normalization mutates or replaces the original request used for evidence. | Own the original immutable `RequestText`; store normalized text separately and test original byte equality. |
| P0 | A normalized span maps to the wrong original bytes after composition or canonical reordering. | Map whole grapheme normalization units, bind spans to one source, and require exact bidirectional round trips. |
| P1 | NFKC, accent stripping, case folding, or confusable folding silently aliases distinct commands or entities. | Fix NFC only and test compatibility, accent, case, and cross-script distinctions. |
| P1 | An interior UTF-8 byte or combining-sequence boundary is accepted as evidence. | Validate character and mapping-unit boundaries independently. |
| P1 | Invisible joiners, bidi controls, variation selectors, tags, or fillers alter downstream interpretation. | Reject the explicit zero-width/default-ignorable security set before normalization. |
| P1 | Newline, tab, NUL, C1, or another control creates hidden structure. | Reject every `char::is_control()` scalar. |
| P1 | Byte-bounded input creates excessive scalar, grapheme, token, or mapping work. | Enforce independent exact scalar, grapheme, and Unicode-word limits before promotion. |
| P1 | Unicode library and conformance data versions drift. | Pin exact archives and lockfile checksums; assert both runtime crates report Unicode 17.0.0. |
| P1 | A dependency introduces network, process, build-script, or ambient behavior. | Audit the exact feature closure and scan vendored source; allow no build scripts or network-capable edge. |
| P2 | Technical Unicode conformance strings are reported as PT-BR linguistic accuracy. | Classify them as test-only standards data and exclude them from linguistic metrics. |
| P2 | A span from equal bytes in another request is accepted. | Use source identity, not byte equality, for both original and normalized spans. |

## Required Tests

Tests cover:

- every Unicode 17.0.0 normalization conformance row for NFC and idempotence;
- every official extended-grapheme and default-word-boundary conformance row;
- precomposed/decomposed accents, canonical mark reordering, Hangul
  composition, and leading combining marks;
- unchanged original bytes and full-span/per-unit normalized-original
  round trips;
- reversed, empty, out-of-range, non-character, non-unit, and foreign-source
  spans;
- C0, C1, line, tab, bidi, joiner, soft-hyphen, variation-selector, tag,
  filler, and byte-order-mark rejection;
- Latin/Cyrillic and Latin/Greek confusable distinction;
- NFC versus NFKC and accent-preservation metamorphic cases;
- exact and one-over byte, scalar, grapheme, and word limits;
- deterministic repeat construction and dependency Unicode-version checks.

## Failure Policy

Malformed UTF-8 remains rejected by `RequestText`. P04 returns typed errors for
policy, limit, span, or normalization-boundary failures and does not return a
partial normalized value. It never rewrites the source, guesses an offset,
deletes an invisible scalar, or substitutes a folded value.

No fourth pre-candidate approach or fourth frozen candidate is allowed.
Routine acquisition or command retries do not consume a pass; selecting a
different normalization form, source portfolio, mapping unit, or limit model
does.

## Counterexample

Accepting zero-width joiner and then deleting it during normalization appears
to produce clean text, but two byte-distinct requests become the same semantic
input while evidence spans no longer account for the deleted bytes. P04 must
reject the scalar explicitly rather than hide it.

Evidence inspected: `AGENTS.md`, source and distribution policy, P04 and
shared requirements, trust boundaries, dependency source, Unicode 17.0.0
conformance inputs, and existing checked-span implementation.
