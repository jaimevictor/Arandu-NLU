# P10 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `01a04b69-4a5e-7a03-b588-d5f434dc339c`
- Input commit: `51c34c62ecc5afbc712e7e9dadc44a4117a445f9`
- Input tree: `797911bbe201120038ef15bb297a8702ffe5411b`
- Mode: read-only independent primary-evidence inspection
- Independence: no edits, network, siblings, internal/Amazon, or closed engine
- Result: `ANALYSIS_COMPLETE_NO_TRUE_BLOCKER`

## Mandatory Scope

P10 owns `P10-HA-001..018`, `P10-HA-021..022`, and
`P10-HA-026..032`. It shares later acceptance for `P10-HA-019..020`,
`P10-HA-023..025`, `P10-ACT-001..004`, and `P10-ROLL-001..002`.

The minimum P10 result pins the official Home Assistant contract, constructs
immutable generation-bound catalog snapshots, preserves entity, device, area,
floor, domain, alias, and typed-capability associations, resolves exact
evidence deterministically, clarifies every equal best candidate, and defines
a complete machine-readable disposition for every pinned built-in entity
platform domain.

Applicable inherited obligations include `USR-001..004`, `USR-008..014`,
`GLB-ENTITY-001..002`, `GLB-SAFE-001..003`, `GLB-DET-001..003`,
`GLB-SEM-001..007`, `GLB-PRIV-002`, `GLB-PRIV-005..009`,
`GLB-SEC-001`, `GLB-SEC-009..011`, and the all-phase Cargo, FOSS,
provenance, clean-room, lifecycle, and bounded-round contracts.

## Official Contract Baseline

The selected public baseline is Home Assistant Core tag `2026.8.3`, commit
`759e4658f40b3ccb671d418b8a0ed95224bf4561`, tree
`f4a72534bb33abf8b5d183910a0c134b968af2f8`, under Apache-2.0.
The exact registry, exposure, intent, and generated entity-platform paths and
hashes are recorded in `docs/evidence/P10-SOURCES.yaml`.

The selected contract establishes:

- stable registry entry IDs distinct from mutable dotted entity IDs;
- explicit entity aliases, area and device associations, capabilities, and
  domain;
- stable device, area, and floor IDs and area-to-floor associations;
- explicit conversation exposure decisions;
- 45 generated built-in entity-platform domains;
- 20 built-in Home Assistant intent constants.

These files define interoperability contracts only. They are not linguistic
data, training data, evaluation gold, dependencies, or copied source payloads.
The rejected Home Assistant intents repository and non-commercial developer
documentation remain unusable.

## Reconciliation

The dotted Home Assistant entity ID is externally meaningful but may change.
The Home Assistant registry entry ID is the stable entity identity. P10 must
therefore preserve both and injectively map the stable registry ID into the
existing core `EntityId` as `ha_entity:id_<registry-id>`. The fixed prefix is
required because the core local component cannot begin with a digit. Mapping
the dotted ID directly into the core ID would violate stable-identity
semantics.

Catalog names, aliases, IDs, locations, devices, and complete snapshots are
sensitive residential data. They may exist in bounded memory but must be
redacted from `Debug`, errors, logs, metrics, fixtures, and committed evidence.
Only opaque `FIXTURE_TECNICA` values may exercise these contracts.

P10 may catalog every valid future domain, but an unknown domain is not an
action path. State queries require a reviewed typed descriptor. Actions remain
unsupported until an explicit operation schema, capability check, risk-policy
mapping, and adapter mapping are all present in later phases.

## Minimum Acceptance

1. Pin the exact official source revision, license, selected path bytes, and
   45-domain and 20-intent inventories.
2. Build an immutable snapshot only after validating the complete bounded
   input and every cross-record association.
3. Preserve stable entity, device, area, floor, domain, capability, alias, and
   generation fields without conflating registry IDs and dotted entity IDs.
4. Include only entities explicitly exposed to Home Assistant conversation.
5. Normalize only to NFC for exact comparison. Do not case-fold, strip
   accents, transliterate, fuzzy-match, or fold confusables.
6. Rank exact dotted entity ID above exact explicit registry alias, and rank
   exact display name only when independent domain, capability, area, floor,
   or device evidence also matches.
7. Attach checked source spans to every ranking factor. Display name alone
   never resolves.
8. Return every equal best candidate in stable-ID order as one entity-specific
   clarification. Insertion position never selects a target.
9. Reject stale generations and publish a fully built snapshot with one atomic
   compare-and-swap operation. A request retains one immutable snapshot.
10. Keep all diagnostics and `Debug` output free of residential values.
11. Disposition all 45 pinned domains in a strict machine-readable artifact.
    Catalog presence may be supported while unreviewed state queries and
    actions explicitly abstain.
12. Prove unknown-domain cataloging, descriptor disable/narrow behavior,
    malformed input rejection, exact one-over limits, insertion permutations,
    concurrent publication, and inherited gates.

## Bounded Convergence

One pass is one selected and dispositioned tuple of official source baseline,
snapshot model, stable-ID mapping, resolution evidence/ranking, atomic store,
descriptor boundary, coverage artifact, privacy controls, and tests. P10 has
at most three convergence passes and three frozen candidate rounds.

The selected source and architecture are pass 1. Candidate round 1 is the
first complete minimum implementation. Rounds 2 and 3 are blocker-only. The
first acceptable candidate is frozen immediately; optional refinement is not
permitted.

## Counterexample

Two exposed entities can have the same display name. Choosing the first record
would turn Home Assistant registry order into semantic evidence. With no
independent domain, capability, area, floor, or device evidence, P10 must
abstain; with equal qualifying evidence, it must clarify both stable IDs.

Primary evidence inspected: `AGENTS.md`, clean-room policy and decisions,
P10 and inherited requirement rows, accepted ADRs, the exact selected Home
Assistant Core contract paths, P01 core IDs and generations, and P09
evidence-bearing intent output.
