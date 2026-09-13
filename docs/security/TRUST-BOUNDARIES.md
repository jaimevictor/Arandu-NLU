# Initial Trust and Failure Boundaries

## Zones

1. **Provenance pipeline**: untrusted external candidate bytes enter
   quarantine. Hash, license, schema, limits, and transformation checks are
   mandatory before immutable compiled data is produced.
2. **NLU core**: trusted code operating on untrusted text plus versioned,
   read-only language/catalog/session snapshots. It has no network, filesystem,
   wall-clock, entropy, credential, or execution authority.
3. **Local server**: parses bounded local protocol/Wyoming frames, authenticates
   where required, applies resource limits, and exposes health/reload. It may
   accept local connections but has no outbound network client or Home
   Assistant credential.
4. **Policy**: validates typed plans against risk, capability, freshness, and
   confirmation state. Denial cannot become a partial execution.
5. **Home Assistant add-on adapter process**: sole project process receiving
   the ephemeral Supervisor token. It synchronizes catalog snapshots through a
   pinned read-only API allowlist and authenticates the companion channel. It
   has no effect-producing Home Assistant operation. It and the server use
   distinct unprivileged UIDs and communicate over a bounded group-only Unix
   socket with kernel peer checks.
6. **Companion integration**: project code inside Home Assistant. It receives
   caller `Context` from Home Assistant, never from the remote request, and is
   the execution boundary for caller-authorized, ordered, multi-target,
   sensitive, and full-clarification flows that are partial-safe. It
   authenticates to the adapter with a separately paired in-memory credential,
   binds caller, session, capability, plan, catalog generation, stable
   operation identity, key epoch, nonce, and sequence, and checks the current
   Home Assistant user's permission on every concrete target before each
   effect. It abstains before any effect for unsafe-partial or transactional
   graphs without a reviewed single-operation atomic capability.
7. **Home Assistant**: external mutable system. Returned state and execution
   results are facts, not trusted instructions.

## Primary threats and required controls

| Threat | Boundary | Control and later proof |
| --- | --- | --- |
| Malformed/oversized Unicode or protocol input | Text/server | Byte/depth/count/time limits, checked spans, fuzzing, no panic |
| Ambiguous entity or stale catalog | Core/adapter | Stable IDs, generation binding, clarification/abstention, revalidation |
| Utterance-to-arbitrary-service injection | Intent/policy | Closed typed operation schemas; no raw service names/payloads |
| Negation or multi-intent scope loss | Intent graph | Span evidence, explicit scope/relations, contradiction tests |
| Sensitive action without consent | Policy/adapter | Deny by default, risk class, capability-bound confirmation |
| Caller identity loss or substitution | Companion/adapter | Original HA context, authenticated channel, caller-bound plan and result checks |
| Replay, race, or session confusion | Dialogue/policy | Opaque session/capability IDs, TTL, one-time consumption, model checks |
| Credential disclosure | Adapter/logs | Separate UIDs, environment allowlists, procfs isolation, process-memory-only pairing secrets, restart revocation, structured redaction tests |
| Concurrent or background HA effects | Companion/HA | Safe-handler allowlist, typed indeterminate timeout, no blind retry, partial-safe sequential stop, pre-effect abstention for atomic-only graphs |
| Companion peer substitution or replay | Companion/adapter | Local pairing, mutually authenticated encryption, key epochs, transcript binding, nonces, sequence windows, fail-closed rotation |
| Residential-data disclosure | Adapter/dialogue/logs | Memory-only utterances/sessions, no telemetry, no default catalog persistence, sentinel leak tests |
| Dependency/data substitution | Build/data | Immutable hashes, lockfile, signed provenance when available, offline build |
| Poisoned or mislicensed corpus | Quarantine | Rights-scope review, per-entry lineage, removal test, adversarial admission |
| Runtime network escape | Core/server | No network dependencies and network-denied integration test |
| Resource exhaustion | All parsers/state | Explicit quotas, bounded collections, cancellation, benchmark/exhaustion tests |
| Non-reproducible package | Build | Pinned FOSS tools, normalized metadata, two-directory digest comparison |

## Failure semantics

Malformed input returns a bounded protocol error. Unknown language evidence,
unsupported capabilities, ambiguity, contradiction, stale state, or low margin
returns clarification or abstention. Adapter failures return typed execution
results and never rewrite interpretation. No error path fabricates a plan.

## Sensitive local data

Utterances, entity IDs and display names, aliases, devices, areas, floors,
catalog snapshots, session state, caller context, and confirmation state are
sensitive residential data. They must not enter logs, metrics labels, errors,
crash dumps, diagnostic bundles, test fixtures, or telemetry. Core dumps are
disabled in the add-on. Session and utterance data is memory-only with bounded
TTL. Catalog state is rebuilt from Home Assistant and is not persisted by
default. The adapter process receives the Supervisor token; every other project
process starts from an explicit environment allowlist that excludes it. The
adapter and server use distinct unprivileged identities, and P14 proves the
server cannot inspect adapter environment or memory through procfs.
