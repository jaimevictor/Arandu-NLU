# ADR-0010: Unicode normalization and reversible span mapping

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-28
- Owners: P04-P08, P15

## Context

The engine must preserve request bytes while later language layers operate on
canonically equivalent text. NFC can compose and reorder scalars, so normalized
byte offsets cannot be copied onto the original string. Invisible formatting
characters and compatibility folding can also create security-relevant aliases.

## Decision

Add `lang-ptbr` as a library depending on dependency-free `nlu-core`, exact
`unicode-normalization` 0.1.25, and exact `unicode-segmentation` 1.13.3. Both
libraries use Unicode 17.0.0 tables.

Keep the original `RequestText` unchanged and store NFC separately. Normalize
each original extended grapheme cluster, verify that concatenating those units
equals whole-string NFC, and retain a monotonic table between normalized and
original unit boundaries. A normalized span is accepted only at UTF-8 and
mapping-unit boundaries and is bound to one normalized source identity.

Do not apply NFKC, case folding, accent removal, transliteration, or confusable
skeletons. Preserve confusables as distinct. Reject Unicode controls and the
versioned explicit format/default-ignorable set rather than deleting them.

Enforce 65,536 input bytes, 32,768 Unicode scalars, 16,384 extended grapheme
clusters, and 4,096 Unicode words. Freeze benchmark word counting as Unicode
17.0.0 default word behavior from `unicode-segmentation` 1.13.3, independent of
the P05 tokenizer.

Test the implementation against the complete official Unicode 17.0.0 NFC,
extended-grapheme, and default-word-boundary conformance files.

## Alternatives

1. Normalize in place. Rejected because evidence must retain original bytes.
2. Infer offsets by scalar diff. Rejected because composition and reordering
   do not have a reversible scalar alignment.
3. Use compatibility folding. Rejected because it aliases distinct input.
4. Hand-maintain Unicode tables. Rejected because pinned official-table
   libraries have a smaller auditable risk surface.

## Consequences

- Evidence spans use original bytes; language processing may use NFC.
- A span cannot split a composed/reordered normalization unit.
- Inputs containing invisible format controls fail before tokenization.
- Unicode-version changes require new sources, conformance replay, and an ADR
  superseding this one.

## Rollback

Remove `lang-ptbr`, its exact dependency closure, and Unicode conformance data.
Do not retain normalized offsets without their original-source mapping.
