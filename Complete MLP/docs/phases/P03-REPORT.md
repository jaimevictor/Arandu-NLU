# P03 Deterministic Data Pipeline Report

- Phase: `P03`
- State: `COMPLETE`
- Subject: `80672238116c125a4174329ce03e67ac88f42d5f`
- Subject tree: `a5296aa0e7d2f4013974a8b9fbce2bd5650802d8`
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P03 adds the real Rust `nlu-data` library and CLI. It verifies the authorized
P02 source package, imports and canonicalizes JSONL records, enforces the
frozen family-disjoint split, compiles a deterministic length-delimited
package, and removes all records for a requested source ID.

The CLI provides `fetch`, `verify`, `import`, `normalize`, `validate`, `split`,
`compile`, and `remove-source`. Fetch is denied without `--allow-fetch` and
supports only an explicit local source root. No network dependency, build
script, training runtime, or external service was added.

ADR-0009 fixes the component boundary, strict source and stage manifests,
atomic immutable stages, canonical JSON rules, and
`nlu-data-package-v1` format. Three closed JSON schemas publish those
contracts.

## Validation

The full inherited Rust gate, focused gate mutations, P02 validator, P02
mutation suite, and P02 generation check pass. The `nlu-data` tests contain 10
unit and 6 integration tests. Two complete CLI builds produce byte-identical
18,511,641-byte packages with SHA-256
`2d76e521b09b37dadba63487e62486193cd2ad5217c70cc8944ee0294deb5905`.

Corrupt bytes, unsafe paths, manifest defects, restricted licenses, missing
provenance, technical fixtures, duplicate identities, split leakage, implicit
fetch, and destination reuse fail closed. Source removal recompiles to a valid
17-byte zero-record package with no source IDs.

Exact commands, mutation classes, counts, and hashes are recorded in
`docs/evidence/P03-VALIDATION.md`.

## Boundaries

The only linguistic input remains the Apache-2.0
`PROJECT_AUTHORED_SYNTHETIC` corpus authorized by `USR-016`. Its manifest uses
explicit repository-local source and license locators instead of invented
external facts. It supports internal conformance only.

P03 does not add language interpretation, morphology, tokenization, parsing,
runtime package loading, policy, execution, Home Assistant transport, response
rendering, or release packaging. Those remain later phases.

## Convergence

Pre-candidate approach 1 of 3 was selected: one Rust package using only the
existing Serde dependency closure. The first complete acceptance attempt found
three warnings-denied Clippy findings; they were corrected before freeze and
the entire gate passed on rerun.

This is candidate round 1 of 3 and the first minimally acceptable baseline.
It is frozen immediately. Remaining rounds are available only for reproduced
P0-P2 blockers; no optional refinement pass follows.

## Review State

The user directed the executor to skip the final review after the successful
run and move on. No independent review result is claimed or fabricated. The
unavailable independent pre-phase and post-phase roles are waived for this
P03 closeout only.

The exact candidate commit and tree reproduced in a no-hardlink clone using
the hash-pinned offline toolchain. The complete inherited gates passed again,
and the compiled package matched the pre-freeze bytes and digest.

## Next State

This evidence-only closeout commits the exact candidate identity, closes P03,
and advances the queue to P04 Unicode text and span handling. No optional P03
review or refinement pass follows.
