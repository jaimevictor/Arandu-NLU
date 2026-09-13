# P10 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04b69-5289-77b2-a688-cb3a506b8164`
- Input commit: `51c34c62ecc5afbc712e7e9dadc44a4117a445f9`
- Input tree: `797911bbe201120038ef15bb297a8702ffe5411b`
- Mode: read-only independent primary-evidence inspection
- Constraints: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `CONVERGENCE_PASS_1_SELECTED`

## Selected Boundary

Add one authority-free production crate:

```text
nlu-core + lang-ptbr <- ha-catalog
intent-engine + ha-catalog <- P11 graph composition
```

`ha-catalog` owns `model`, `snapshot`, `resolve`, `store`, `coverage`, and
`error` modules. It has no filesystem, network, execution, policy, protocol,
response-rendering, clock, entropy, persistence, credential, or Home
Assistant authority. P14 will translate live Home Assistant records into its
bounded input types.

The crate retains exact external Home Assistant IDs separately. A stable
registry entry ID maps injectively to core `EntityId` as
`ha_entity:id_<registry-id>` so digit-leading IDs satisfy the existing core
identifier grammar. Dotted `domain.object_id` values never become core stable
IDs.

## Immutable Snapshot

`CatalogSnapshot::build` validates a complete input before returning an
immutable value. It canonicalizes all collections into stable order and
rejects duplicate IDs, duplicate dotted entity IDs, dangling device/area/floor
or capability references, inconsistent domains, invalid text, stale or zero
generations, and exact one-over resource limits.

Only enabled records explicitly exposed to the Home Assistant `conversation`
assistant enter the snapshot. Explicit exposure remains authoritative for a
hidden entry because hidden status only affects Home Assistant's default
exposure calculation. Every entity record carries the snapshot generation and
preserves its domain, capabilities, area, floor, device, and explicit entity
alias associations. The pinned device registry exposes no alias field.

Stable device, area, floor, domain, and external entity IDs use separate
closed types. Area and floor IDs are slug-derived registry IDs, while entity
and device registry IDs use UUID-hex values. Residential strings preserve
their original UTF-8 bytes and store an NFC comparison key. Their `Debug`
implementations and every public error expose only type, code, and bounded
counts.

## Resolution

Resolution receives one snapshot, one generation-bound query, and checked
half-open evidence spans into the original request. Matching is exact NFC and
uses no case folding, accent removal, fuzzy distance, transliteration,
stemming, locale input, or confusable folding.

Candidates are filtered by every supplied typed constraint and ranked:

1. exact external Home Assistant entity ID;
2. exact explicit registry alias;
3. exact display name plus at least one independent domain, capability, area,
   floor, or device constraint.

Every match returns a closed explanation containing the factor kind and its
checked source evidence. Display name alone abstains. Equal best candidates
are all returned in one P10-specific clarification, ordered only by stable
entity ID. Stable ordering cannot select a winner.

## Descriptor And Coverage Boundary

Domains are validated strings rather than a closed Rust enum so future Home
Assistant domains remain catalogable. Typed capability descriptors may enable
or narrow state-query support for selected domains. Disabling or narrowing a
descriptor changes data, not core types.

P10 exposes no generic service name and no action construction API. An
unknown or unreviewed capability remains non-actionable. Later action support
must add all four independently reviewed prerequisites: typed operation
schema, capability check, risk-policy mapping, and adapter mapping.

A strict canonical coverage artifact pins all 45 generated entity-platform
domains and all 20 built-in intent constants from Home Assistant 2026.8.3.
Each domain explicitly reports catalog presence, state-query, and action
dispositions indexed by operation and capability. The minimum P10 artifact
supports catalog presence and abstains for state queries and actions without a
reviewed descriptor.

## Atomic Publication

`CatalogStore` holds `Arc<CatalogSnapshot>` behind `RwLock`. A reload builds
and validates the next snapshot before acquiring the write lock, then checks
the expected current generation and swaps the complete `Arc` in one critical
section. Concurrent publishers from the same expected generation cannot both
succeed.

Each request clones one snapshot `Arc` before resolution. A later reload
cannot expose mixed generations or mutate the retained snapshot.

## Required Verification

- stable-ID mapping and preservation of all associations;
- disabled, hidden, unexposed, duplicate, malformed, and dangling records;
- alias/display/external-ID collisions and contradictory constraints;
- exact NFC equivalence plus case, accent, compatibility, and confusable
  negatives;
- complete ranking explanations with source-owned spans;
- entity and input insertion permutations;
- stale, skipped, overflowed, and concurrent generations;
- retained old-snapshot coherence after publication;
- unknown-domain cataloging and descriptor extension, disable, and narrowing;
- privacy-safe errors and `Debug` output with residential canaries;
- strict 45-domain and 20-intent coverage/source mutations;
- exact one-over limits, focused Cargo checks, and inherited phase gates.

## Bounded Completion

This is convergence pass 1 of at most 3. Candidate round 1 is the first
complete minimum implementation; later rounds are blocker-only. Freeze the
first passing minimum and perform no optional refinement.

## Counterexample

An entity alias collision survives every stable sort. Returning only the
lowest stable ID would be deterministic but semantically unsupported.
Resolution must return both candidates as clarification with identical
evidence ranks.

## Rollback

Before acceptance, remove the P10 crate, coverage artifact and schema,
validator, source record, and ADR. P09 remains intact. After acceptance,
supersede the ADR and version affected coverage or snapshot contracts instead
of rewriting accepted bytes.

Primary evidence inspected: P10 requirements, clean-room policy, accepted
ADRs, exact Home Assistant registry/exposure/domain/intent contracts, P01
core identity and generation types, and P09 unresolved mention evidence.
