# ADR-0003: Rust core architecture and invariants

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P01, P04-P13

## Context

P01 must establish stable contracts before linguistic behavior or networking
exists. The contracts need deterministic serialization, checked Unicode spans,
multi-intent plans, extensible Home Assistant semantics, and invalid-state
rejection.

The official Rust stable manifest retrieved on 2026-08-24 identifies Rust
1.98.0, dated 2026-08-20.

## Decision

Use Rust 1.98.0, Edition 2024, with `rust-version = "1.98"` and an exact
`rust-toolchain.toml` pin. The lockfile is versioned. P01 begins with:

- `nlu-core`: initially standard-library-only domain types and traits;
- `protocol`: strict wire DTOs and conversion validation, depending on
  `nlu-core`; core never depends on protocol.

Text spans are checked half-open UTF-8 byte ranges. Raw offsets are private,
must fit fixed-width unsigned values, must be ordered and in range, and must
start/end on UTF-8 character boundaries. The immutable original string remains
the source of truth.

Stable identifiers are validated opaque strings with explicit namespaces.
Plans contain ordered nodes, typed slots, evidence spans, entity references,
and typed relations. They do not contain Home Assistant credentials, arbitrary
service names, unvalidated JSON payloads, or execution callbacks.

Core confidence and ranking values use bounded integers or fixed-point values,
not floating point. Ordered vectors or sorted maps define all observable
ordering. An understood outcome requires a non-empty valid plan;
clarifications use stable option IDs; malformed combinations are rejected by
constructors and DTO conversion.

## Alternatives

1. A single crate with serialized public structs. Rejected because protocol
   evolution would leak into core invariants.
2. Character or grapheme offsets. Rejected as the sole boundary coordinate
   because Rust slicing and wire payloads are byte-oriented. Later layers may
   expose derived scalar/grapheme coordinates with explicit types.
3. A closed enum for every Home Assistant domain/action. Rejected because
   domain growth would require protocol breaks.
4. Floating-point confidence. Rejected because NaN, representation, and
   platform details complicate canonical ordering and serialization.

## Consequences

- Constructors and conversion code carry more validation work.
- Protocol DTOs duplicate selected core fields intentionally.
- P01 can test safety and determinism without inventing Portuguese examples.

## Rollback

The exact Rust pin may be advanced through a tested ADR amendment. Protocol
mistakes create a new wire version; they do not weaken core invariants.
