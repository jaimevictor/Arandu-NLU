# P04 Pre-phase Architecture Analysis

- Role: `executor-architecture-synthesis`
- Analysis instance: `p04-executor-architecture-20260828`
- Input baseline: `c2685e4ca931ce631f329aa36f652ec4c436b49d`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Selected Structure

Add one non-placeholder Rust library, `crates/lang-ptbr`, depending on
`nlu-core`, exact `unicode-normalization` 0.1.25, and exact
`unicode-segmentation` 1.13.3. `nlu-core` remains dependency-free.

`NormalizedText` owns:

- the original immutable `RequestText`;
- one NFC-normalized string;
- a monotonic boundary table from normalized grapheme-unit byte offsets to
  original byte offsets;
- checked scalar, grapheme, and Unicode-word counts.

Construction validates policy and limits before returning a usable value.
Normalization runs independently over original extended grapheme clusters,
concatenates the results, and verifies that this equals whole-string NFC. Each
unit therefore has one contiguous original range and one contiguous normalized
range. The table starts at zero and ends at both string lengths.

`NormalizedSpan` is source-bound and contains private checked half-open UTF-8
byte offsets. A span is accepted only when both ends are character boundaries
and mapping-unit boundaries. Converting it to an original `Utf8Span` and back
must reproduce the exact normalized span. Original spans from another request
or spans whose ends split a normalization unit fail closed.

## Unicode Policy

- Normalization: NFC under Unicode 17.0.0.
- Compatibility decomposition/folding: never.
- Case folding: never in P04.
- Accent removal: never.
- Combining marks: retained and canonically composed/reordered by NFC.
- Controls: every Unicode control scalar is rejected.
- Zero-width/default-ignorable security set: explicit versioned ranges are
  rejected before normalization, including joiners, bidi controls, variation
  selectors, tags, fillers, soft hyphen, and byte-order mark.
- Confusables: retained as distinct bytes/scalars; no skeleton or alias is
  generated.

The word-count algorithm is frozen as Unicode 17.0.0 default word-boundary
behavior implemented by `unicode-segmentation` 1.13.3. It is independent of
the P05 tokenizer and exists only for resource limits and later benchmark
denominators.

## Limits

The inherited request byte limit remains 65,536. P04 additionally fixes:

- 32,768 Unicode scalar values;
- 16,384 extended grapheme clusters;
- 4,096 Unicode words.

Counts use checked traversal and are recorded once at construction. Mapping
storage is bounded by the grapheme limit plus the initial boundary.

## Source And Distribution

Retain exact official Unicode 17.0.0 `NormalizationTest.txt`,
`GraphemeBreakTest.txt`, and `WordBreakTest.txt` bytes plus the complete
Unicode License V3 text. They are test-only technical conformance data and do
not enter runtime artifacts or linguistic metrics.

Vendor the four exact crates from their crates.io package archives. Preserve
their generated checksum manifests, VCS metadata, and complete license files.
Update the dependency and distribution ledgers so every new path has one
origin.

## Alternatives

1. Hand-write normalization and segmentation tables. Rejected because the
   official table-driven crates are smaller-risk, versioned, and fully
   conformance-tested.
2. Put Unicode dependencies in `nlu-core`. Rejected because core's stable
   dependency-free boundary need not change.
3. Normalize the whole string and infer offsets by scalar comparison.
   Rejected because composition and canonical reordering make scalar alignment
   ambiguous.
4. Use NFKC or confusable skeletons. Rejected because they erase distinctions
   and create unsupported aliases.
5. Preserve zero-width controls and defer policy. Rejected because later
   tokenization could interpret invisible structure inconsistently.

## Counterexample

A whole-string NFC value can be correct while its offset map is wrong. For
original bytes representing `D`, combining dot above, and combining dot below,
NFC reorders and composes. Byte-diff alignment cannot decide which normalized
byte belongs to which original scalar. One grapheme-unit mapping remains
contiguous and reversible.

Evidence inspected: P04 requirements, `nlu-core` text contracts, workspace and
vendor configuration, Unicode crate source/manifests, UCD 17.0.0 conformance
headers, and existing phase architecture records.
