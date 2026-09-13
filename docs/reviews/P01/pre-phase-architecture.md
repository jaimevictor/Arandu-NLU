# P01 Pre-phase Architecture Analysis

- Role: `phase-architect`
- Reviewer instance: `01a044c8-0f51-7b13-8022-f98da1468161`
- Input baseline: `ec2f05c4ecc0411b1ff010b31a5199de127cc413`
- Mode: read-only
- Result: `ANALYSIS_COMPLETE`

P01 creates two real library crates with dependency direction
`protocol -> nlu-core -> std`. Core remains standard-library-only. Neither
crate may contain binaries, build scripts, transport, framing, authentication,
policy, execution, response rendering, concrete-language behavior, Home
Assistant authority, or ambient network/filesystem/environment/time access.

## Core Contract

- `RequestText` owns immutable original UTF-8 bytes. A checked `Utf8Span`
  retains that source identity plus private `u32` half-open offsets so a span
  cannot be reused unchecked against different text.
- `StableId` has bounded nonempty ASCII namespace/local components. Domain
  newtypes prevent interchange of intent, slot, node, entity, option,
  capability, and operation identifiers.
- Confidence uses basis points; rank and fixed-point values use bounded
  integers. No core or protocol float exists.
- Entity references require a nonzero catalog generation.
- Slot values are closed typed variants. Plans use explicit ordered nodes,
  canonical slots and relations, checked evidence spans, and validated entity
  references. Constructors reject empty plans, duplicates, dangling or
  self-references, and relation cycles.
- Plans expose semantic capability and operation identifiers only. They cannot
  carry credentials, raw Home Assistant service names, arbitrary JSON,
  payloads, callbacks, or authority-bearing objects.
- Core has exactly three semantic outcomes: plan, clarification, and
  abstention. The protocol envelope adds the fourth protocol-error outcome.
- Logical time and opaque invocation-ID creation are explicit injected traits.
  Their values are inputs or nonsemantic metadata and never enter semantic
  output.

## Protocol Contract

Version 1 is strict UTF-8 JSON. DTOs under `protocol::v1` are distinct from
core types and invoke core constructors during conversion. Exact-pinned,
vendored `serde` and `serde_json` are admitted only for `protocol`; decoding is
directly into closed DTO structs with unknown-field rejection and never
through an arbitrary JSON value tree.

A linear preflight rejects invalid UTF-8, more than 65,536 request bytes,
more than 16,384 decoded string bytes, nesting beyond 32, overlong numeric
tokens, and structural exhaustion before Serde allocation. Constructor and DTO
limits additionally bound identifiers to 128 bytes, hypotheses to 32, plan
nodes to 64, relations to 256, slots per node to 32, evidence spans per item
to 64, clarification options to 16, and aggregate collection items to 4,096.
Protocol error encoding is capped at 256 bytes.

Top-level request and response objects carry `"version":1`. Response tags are
`plan`, `clarification`, `abstention`, and `protocol_error`. Canonical output
is compact UTF-8 JSON without a trailing newline, with fixed struct-field and
tag order, integer-only values, canonical vectors, and no semantically
unordered object DTOs. Parser diagnostics are discarded; closed protocol
errors contain only safe bounded codes and numeric metadata.

Versioned request and response schemas use `additionalProperties:false`,
exact tags, integer ranges, and collection limits. Tests check all four
outcomes, DTO-to-core rejection, hostile JSON, exact canonical bytes, and the
schema subset used by fixtures.

## Build And Evidence Boundary

The P01 reproducibility set is the locked release-profile `nlu_core` and
`protocol` library artifacts plus generated protocol fixtures and schemas.
Two clean absolute roots use identical admitted tools, target, arguments,
locale, timezone, `SOURCE_DATE_EPOCH`, and per-root path remapping; matching
relative artifact inventories and SHA-256 values are required. P01 emits no
OCI or distribution archive, so external archive ownership/order checks are
not applicable until their owning packaging phase.

Before candidate freeze P01 must provide a non-circular P01-to-P02 checkpoint
validator, complete tool/dependency/license provenance, exact Cargo gates,
source-boundary scans, canonical snapshots, and distinct-root reproduction.

## Alternatives And Counterexample

A standard-library JSON implementation avoids dependencies but duplicates
Unicode escape, surrogate, number, duplicate-key, and trailing-input logic.
The proven parser plus bounded preflight has lower correctness risk despite
its admission cost.

`{"version":1,"request":{"text":"FIXTURE_TECNICA_A","text":"FIXTURE_TECNICA_B"}}`
must fail as a duplicate. Decoding through an arbitrary value map could erase
that evidence and is prohibited.

Evidence inspected: `AGENTS.md`, ADRs 0001, 0003, 0004, 0006, and 0008,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`,
`docs/evidence/TOOLCHAIN-PROVENANCE.yaml`, and the source policy. Commands used
were read-only `find`, `grep`, `sed`, and Git inspection.
