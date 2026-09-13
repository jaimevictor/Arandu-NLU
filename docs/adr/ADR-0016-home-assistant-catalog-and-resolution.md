# ADR-0016: Home Assistant catalog and exact-evidence resolution

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-28
- Owners: P10-P15

## Context

P10 must preserve Home Assistant entity, device, area, floor, domain, alias,
capability, and generation contracts while keeping interpretation independent
from Home Assistant authority. Entity resolution must be deterministic,
auditable, privacy-safe, and fail closed when evidence is insufficient or
ambiguous.

Home Assistant Core 2026.8.3 distinguishes a stable entity-registry entry ID
from its externally visible dotted entity ID. Its exact Apache-2.0 registry,
conversation-exposure, intent, and generated entity-platform contract paths
are pinned in `docs/evidence/P10-SOURCES.yaml`. They establish 45 built-in
entity-platform domains and 20 built-in intent constants. No source bytes are
copied and no Home Assistant language repository is admitted.

## Decision

Add one production `ha-catalog` crate:

```text
nlu-core + lang-ptbr <- ha-catalog
```

The crate has no network, filesystem, execution, policy, protocol,
response-rendering, time, entropy, persistence, credential, or Home Assistant
authority.

### Identity And Snapshot

Preserve the exact external Home Assistant registry ID and dotted entity ID as
separate fields. Injectively map a valid stable registry ID to core
`EntityId` as `ha_entity:id_<registry-id>`; the fixed `id_` prefix satisfies
the core local-component grammar for digit-leading registry IDs. Never map the
mutable dotted ID to core stable identity.

Build a complete immutable `CatalogSnapshot` under explicit entity, relation,
alias, capability, candidate, and aggregate byte limits. Construction rejects
duplicate IDs, duplicate dotted entity IDs, malformed names or IDs,
inconsistent domains, dangling area/floor/device/capability associations,
invalid generations, and limit violations before producing a snapshot.

Only enabled records explicitly exposed to the Home Assistant `conversation`
assistant enter the snapshot. An explicit exposure decision is authoritative
even when the registry entry is hidden; hidden status affects only Home
Assistant's default exposure calculation. Every entity record carries the
snapshot generation and preserves its domain, capabilities, area, floor,
device, and explicit entity aliases. The pinned device registry has no alias
field. Stable domain, device, area, and floor IDs use distinct types; area and
floor IDs are slug-derived registry IDs rather than entity/device UUID hex.

All residential text preserves its original UTF-8 bytes. A separate NFC key
supports exact canonical comparison. No case folding, accent removal,
compatibility normalization, fuzzy matching, transliteration, stemming,
locale-sensitive transform, or confusable folding is permitted.

### Resolution

Resolution receives an immutable snapshot and a generation-bound query whose
mention and constraints each carry a checked half-open span into one original
request. Every supplied typed constraint is mandatory.

Candidate evidence ranks in this order:

1. exact external Home Assistant entity ID;
2. exact explicit registry alias;
3. exact display name plus at least one matching independent domain,
   capability, area, floor, or device constraint.

Display name alone abstains. A candidate explanation contains every ranking
factor and its checked source span. Equal best candidates are returned in one
entity-specific clarification, canonically ordered by stable entity ID.
Ordering never selects a winner.

### Descriptor And Coverage Boundary

Domain values are open validated strings so future domains remain catalogable.
Reviewed typed capability descriptors may enable state-query support for
selected domains. A descriptor can be disabled or narrowed without changing
core types.

P10 exposes no generic service name and no action construction API. An action
remains unavailable until later phases provide all four prerequisites:
explicit typed operation schema, explicit capability check, explicit
risk-policy mapping, and explicit adapter mapping.

The versioned canonical P10 coverage artifact indexes all 45 pinned domains by
domain, operation, and capability and records the 20 built-in intent
constants. The minimum disposition supports catalog presence and explicitly
abstains for state queries and actions that lack a reviewed descriptor.
Unknown future domains remain catalogable and non-actionable.

### Atomic Publication And Privacy

`CatalogStore` owns one `Arc<CatalogSnapshot>` behind `RwLock`. The caller
builds and validates a replacement outside the lock. Publication checks the
expected current generation and atomically swaps the complete `Arc`.
Concurrent publishers from one generation cannot both succeed. A request
clones one snapshot `Arc` and therefore cannot observe mixed generations.

Catalog names, IDs, aliases, locations, devices, and complete snapshots are
sensitive residential data. Their `Debug`, display errors, metrics, and
validation output reveal only closed codes and bounded counts. Tests use only
opaque `FIXTURE_TECNICA` values. Snapshots are memory-only and have no
persistence API.

## Acceptance

Acceptance requires exact source identity and coverage inventories, immutable
snapshot and stable-ID tests, dangling-association and limit rejection,
source-owned ranking explanations, external-ID/alias/display collision and
insertion-permutation tests, exact-NFC and non-equivalence tests, stale and
concurrent publication tests, retained old-snapshot coherence,
descriptor-disable/narrow and unknown-domain tests, privacy canaries, coverage
mutations, focused Cargo checks, and inherited gates.

The first complete implementation that passes mandatory checks is frozen.
Optional refinement is prohibited. At most three convergence passes and three
candidate rounds may be consumed; rounds after the first are blocker-only.

## Consequences

- Stable identity survives a dotted entity-ID rename.
- Catalog breadth can include future domains without enabling arbitrary
  services.
- Entity ambiguities remain explicit rather than being hidden by stable sort.
- P11 can combine P09 mention evidence with one generation-bound catalog
  snapshot.
- P14 remains responsible for acquiring live Home Assistant records and for
  every privileged API call.
- P15 remains responsible for release-level intent and actionable coverage.

## Alternatives

1. Use dotted entity ID as core identity. Rejected because Home Assistant can
   rename it independently of the stable registry record.
2. Select the first display-name or alias match. Rejected because deterministic
   order is not semantic evidence.
3. Case-fold or fuzzy-match residential names. Rejected because it merges
   unsupported alternatives and weakens auditability.
4. Persist snapshots for restart speed. Rejected because Home Assistant is the
   source of truth and snapshots contain residential data.
5. Accept arbitrary `domain.service` strings. Rejected because it collapses
   interpretation, policy, and execution.

## Rollback

Before acceptance, remove the P10 crate, source record, coverage artifact and
schema, validator, and this ADR. P09 remains intact. After acceptance,
supersede this ADR and version affected snapshot, resolution, descriptor, and
coverage contracts instead of rewriting accepted bytes.
