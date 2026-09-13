# P10 Pre-phase Adversarial Analysis

- Role: `independent-adversarial-analysis`
- Analysis instance: `01a04b69-5a77-76e3-8bb7-cab91ee9b891`
- Input commit: `51c34c62ecc5afbc712e7e9dadc44a4117a445f9`
- Input tree: `797911bbe201120038ef15bb297a8702ffe5411b`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE`

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P10-A01` | Residential entity, alias, area, floor, device, or snapshot data enters Git, fixtures, logs, metrics, errors, or diagnostics. Use opaque `FIXTURE_TECNICA` records only and redact every sensitive type and failure path. |
| P0 | `P10-A02` | Rejected Home Assistant intents, non-commercial documentation, closed-engine material, or model-generated language influences resolution. Restrict P10 to exact open contract paths; add no linguistic entries. |
| P1 | `P10-A03` | Mutable dotted entity IDs are treated as stable core identity. Map the registry entry ID injectively and preserve the dotted ID separately. |
| P1 | `P10-A04` | Display name alone selects an entity. Require independent typed evidence or abstain. |
| P1 | `P10-A05` | Alias or display collisions are broken by insertion position or stable-ID order. Return every equal best candidate as clarification. |
| P1 | `P10-A06` | Case folding, accent stripping, fuzzy distance, transliteration, or confusable folding merges distinct residential names. Permit exact NFC equivalence only. |
| P1 | `P10-A07` | A dangling or contradictory area, floor, device, domain, capability, or generation creates a partial snapshot. Validate the whole graph before publication. |
| P1 | `P10-A08` | Concurrent readers observe records from different generations. Build outside the lock and swap one immutable `Arc` after an expected-generation check. |
| P1 | `P10-A09` | A catalogable unknown domain falls through to arbitrary `domain.service` execution. Expose no generic service/action API and require reviewed descriptors. |
| P1 | `P10-A10` | The coverage denominator omits an inconvenient built-in domain or silently implies action support. Pin all 45 domains and require explicit catalog, state-query, and action dispositions. |
| P2 | `P10-A11` | Unbounded aliases, entities, capabilities, text, or candidate sets exhaust memory or time. Apply checked per-record and aggregate limits before publication or resolution. |
| P2 | `P10-A12` | Ranking explanations cite a value but not request evidence, or reuse a foreign span. Require source-owned checked spans for every factor. |
| P2 | `P10-A13` | Source revision, selected path, license, generated domain, or intent inventory is substituted. Pin commit, tree, path sizes/hashes, and aggregate selected-path hash. |
| P3 | `P10-A14` | P10 catalog breadth is reported as action breadth. Coverage language must distinguish catalog presence from reviewed state-query and action support. |

## Required Mutations

1. Substitute the source commit, tree, tag, license, one selected path hash,
   aggregate bundle hash, domain inventory, or intent inventory.
2. Duplicate or mutate a registry ID, dotted entity ID, domain, capability,
   area, floor, device, or alias provenance.
3. Add dangling associations, inconsistent area-to-floor relationships, and
   unexposed entities.
4. Collide external IDs, explicit aliases, and display names under reversed
   insertion orders.
5. Exercise canonical-equivalent NFC input plus case, accent, compatibility,
   Greek/Cyrillic confusable, and malformed-control negatives.
6. Omit independent display-name evidence, contradict one constraint, or
   attach a span from another request.
7. Publish stale, skipped, overflowing, and concurrent generations while
   retaining old snapshot handles.
8. Add an unknown domain or unreviewed capability and attempt state-query or
   action admission.
9. Disable and narrow descriptors without changing Rust types.
10. Put residential canaries in every sensitive field and inspect `Debug`,
    display errors, mutation failures, and test output for disclosure.
11. Delete one of the 45 domain rows, duplicate a row, claim unsupported
    capability/action support, or break operation/capability indexing.
12. Exercise every exact one-over count and byte limit.

## Fail-closed Contract

- An invalid input produces no snapshot.
- An unexposed entity is absent from the published catalog.
- An unknown, contradictory, insufficiently evidenced, or stale query
  produces abstention or a typed error, never a guessed entity.
- Equal best candidates always clarify.
- Only one complete generation is visible through a request snapshot.
- Unknown domains remain catalogable but state-query and action behavior
  remain unavailable without reviewed descriptors.
- No error or debug representation contains residential field bytes.

## Bounded Stop

One convergence pass is one selected source, identity mapping, immutable
snapshot, resolution rule, descriptor boundary, atomic store, coverage
artifact, privacy contract, and mutation portfolio. At most three passes and
three candidate rounds are allowed. The first acceptable candidate is frozen;
rounds 2 and 3 are blocker-only.

After three unsuccessful passes, or with any P0-P2 after candidate round 3,
stop for explicit scope adjudication instead of adding fuzzy heuristics,
fabricating fixtures, weakening privacy, or enabling arbitrary services.

## Counterexample

Two aliases whose original bytes differ only by NFC composition must compare
equal, while an uppercase, accent-stripped, compatibility, or confusable form
must not. If both exact-NFC aliases qualify, the result is clarification, not
the first or lowest-ID entity.

Primary evidence inspected: P10 and inherited requirements, `AGENTS.md`,
clean-room policy, exact selected Home Assistant contract files, accepted
identity/privacy/coverage ADRs, and P01/P09 typed evidence boundaries.
