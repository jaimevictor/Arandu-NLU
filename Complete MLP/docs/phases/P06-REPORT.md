# P06 Provenance-bearing Lexicon Report

- Phase: `P06`
- State: `COMPLETE`
- Subject: `66f1d6aea06d314e873d29ee40fcd447fa9fe7b0`
- Subject tree: `e5d041a21b6453ae043247b4c142313f2704f520`
- Convergence pass: 1 of 3
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P06 adds a direct pinned-source lexical compiler, strict canonical binary
package and sidecar, complete per-entry lineage, source-ID removal, and
private exact-match runtime indexes. Unknown surfaces remain unknown and
equal-surface analyses remain an explicit conflict.

The only linguistic input is the already authorized P02
`PROJECT_AUTHORED_SYNTHETIC` source. P06 performs no external source search,
linguistic inference, correction, ranking, case folding, fuzzy matching, or
winner selection.

## Validation

The P01 through P06 mandatory gates pass. Fresh compilation from the repository
and a copied clean source root plus the CLI reproduce the tracked artifact.
Independent Ruby decoding recomputes source-row, semantic, transform, package,
and inventory hashes for every entry. Mutation tests cover admission,
framing, ordering, resource bounds, lineage, licensing, schema closure, and
complete source removal.

A no-hardlink, no-local clone reproduced the exact candidate and all inherited
and P06 gates offline with a copied admitted toolchain. The clone had no object
alternate and remained clean.

## Convergence

The first integrated source pin, contribution schema, package, runtime index,
and removal design met minimum acceptance in convergence pass 1. Candidate
round 1 was frozen immediately. No optional refinement follows; two
convergence passes and two candidate rounds remain unused.

## Review State

The user directed the executor to skip the final phase review after successful
mandatory gates. No separate post-candidate phase review is claimed.

## Next State

After exact-commit reproduction, the evidence-only closeout advances the queue
to P07 morphology without changing the P06 subject.
