# ADR-0004: Versioned strict JSON protocol

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P01, P13-P15

## Context

The protocol needs a human-auditable initial format, schema validation,
canonical output, forward evolution, hostile-input rejection, and compatibility
with local transports. Transport selection is not required in P01.

## Decision

Version 1 uses UTF-8 JSON DTOs distinct from core types. Every top-level request
and response carries an explicit protocol version. Deserialization rejects:

- unknown versions and outcome tags;
- unknown or duplicate fields;
- trailing input and malformed UTF-8;
- invalid identifiers, spans, graph references, empty plans, and illegal
  outcome combinations;
- inputs over explicit byte, depth, collection, and string limits.

Canonical emission uses fixed struct field order, stable enum tags, ordered
collections, no floats, and no semantically unordered JSON objects. Equivalent
core values must serialize to identical bytes. JSON Schemas are versioned and
checked against implementation fixtures.

Protocol errors are typed and bounded; they do not echo full hostile input.
Transport, framing, and authentication remain P13 decisions.

Protocol v1 decoding remains mandatory throughout P01-P16 and FINAL and in
every release that emits or accepts a v1 request. Removing v1 is outside the
current release scope. It requires a new accepted ADR, a new wire version,
documented migration evidence, and an explicit release requirement; a field
addition or limit relaxation alone cannot end the v1 support window.

## Alternatives

1. CBOR. Smaller, but less directly inspectable and unnecessary before
   performance evidence shows JSON is a bottleneck.
2. Protobuf. Strong schema tooling, but adds code generation and unknown-field
   semantics before the domain contracts stabilize.
3. Serialize core types directly. Rejected because wire compatibility would
   constrain internal evolution and expose invariants incompletely.

## Consequences

- Strict parsing requires negative tests beyond normal Serde round trips.
- Adding a field or relaxing a limit needs compatibility analysis.
- A future binary protocol can map to the same validated core types.
- Version 1 decoding cannot be removed during the current project phase queue.

## Rollback

Introduce a new protocol version and retain v1 decoding for the documented
support window. Core values and traits remain transport independent.
