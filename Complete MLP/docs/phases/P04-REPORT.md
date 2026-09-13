# P04 Unicode Text And Span Report

- Phase: `P04`
- State: `COMPLETE`
- Subject: `cc579ca73ef1b9538338bb33ac11f5383c7ae8c4`
- Subject tree: `482b798caa5674fbc5d703fdfb5a8b33d27e7794`
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P04 adds the real `lang-ptbr` library. It retains original `RequestText`
bytes, stores Unicode 17 NFC separately, and maps normalized extended-grapheme
unit spans reversibly to checked original half-open UTF-8 byte spans.

The library rejects controls and an explicit Unicode 17
format/default-ignorable set. It never applies compatibility folding, case
folding, accent removal, transliteration, or confusable skeletons. Cross-script
lookalikes remain distinct.

Independent limits are fixed at 65,536 input bytes, 32,768 scalars, 16,384
grapheme clusters, and 4,096 Unicode words. The later benchmark word counter is
versioned independently of P05 tokenization.

## Source And Dependencies

The exact official Unicode 17.0.0 UCD archive is admitted under Unicode
License V3. The retained conformance inputs contain 20,034 normalization,
766 grapheme-boundary, and 1,944 word-boundary rows.

The exact runtime additions are `unicode-normalization` 0.1.25,
`unicode-segmentation` 1.13.3, `tinyvec` 1.12.0, and `tinyvec_macros` 0.1.1.
All are permissively licensed, checksum-bound, vendored, and offline. The
complete external closure is 15 packages and 549 verified package files.

## Validation

All 13 `lang-ptbr` tests pass, including every retained official Unicode
conformance row, exact/one-over limits, policy negatives, NFC idempotence,
confusable preservation, and normalized/original span round trips.

The full P01 warnings-denied workspace gate, P04 source gate, 12 total gate
mutation tests, and inherited P02 gates pass. A no-hardlink clone of the exact
candidate and tree reproduced all gates offline with matching source hashes.
Commands and hashes are in `docs/evidence/P04-VALIDATION.md`.

## Convergence And Review

Pre-candidate convergence pass 1 selected the official Unicode 17 source,
table-driven implementation, NFC, grapheme-unit map, and four-limit model.
Candidate round 1 is the first minimally acceptable baseline and was frozen
immediately. No optional second pass follows.

The user directed the executor to skip the final review after the successful
run. No independent review result is claimed or fabricated. Remaining
candidate rounds may be used only if a P0-P2 blocker is later reproduced.

## Next State

This evidence-only closeout advances the queue to P05 tokenization. P05 owns
token boundaries and decision provenance; it must consume P04 spans without
weakening original-byte traceability.
