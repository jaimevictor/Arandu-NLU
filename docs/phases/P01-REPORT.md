# P01 Core And Protocol Report

- Phase: `P01`
- State: `COMPLETE`
- Subject: `eb8e58e92f8ce8896ae81f540de69340c0044630`
- Subject tree: `9fd1a8bd89416e057a5ae5d2b7b63fec52e6fb41`
- Candidate round: 1 of 3
- Result: `MINIMUM_ACCEPTABLE_PASS_WITH_USER_REVIEW_WAIVER`

## Delivered

P01 creates two real Rust 2024 libraries with dependency direction
`protocol -> nlu-core -> std`. Core owns immutable request text, source-bound
checked UTF-8 byte spans, opaque namespaced identifiers, bounded confidence
and collection values, typed entities and slots, deterministic hypotheses,
ordered graph plans, clarifications, abstentions, and injected logical-time
and identifier providers.

Protocol v1 uses distinct strict Serde DTOs and validated DTO-to-core
conversion. A bounded preflight runs before DTO allocation. Decoding rejects
malformed UTF-8 and JSON, duplicate or unknown fields, trailing input,
unsupported versions and tags, floats, invalid spans and identifiers, illegal
graphs and outcomes, and every declared resource excess. Canonical compact
JSON exposes exactly plan, clarification, abstention, or protocol error.

Versioned request and response JSON Schemas and five canonical technical
fixtures are checked against implementation bytes.

## Provenance And Build

Rust 1.98.0 and its selected components are locally pinned by immutable
identity. The 11-package Serde/JSON closure is exact-locked, vendored,
byte-verified, license-indexed, Amazon-exclusion checked, and usable with Cargo
offline. The RustSec snapshot found no advisory naming a locked package; that
limited negative result is not a claim that undisclosed vulnerabilities do not
exist.

The P01 gate passed formatting, all-target/all-feature Clippy with warnings
denied, 45 tests, and all-target builds. Post-freeze reproduction passed in
two clean absolute roots: both release libraries, all five canonical fixtures,
and both schemas had matching relative inventories and SHA-256 values.

## Boundaries

Core has no language implementation, network, filesystem, environment,
wall-clock, entropy, global mutable state, transport, framing, authentication,
policy, execution, response rendering, Home Assistant authority, credential,
service-name, arbitrary-JSON, callback, or external dependency surface.

Protocol has no transport, framing, authentication, policy, execution,
response rendering, network/process API, float DTO, arbitrary JSON value, or
semantically unordered object DTO.

## Convergence

This is the first substantive P01 candidate. It passed the minimum
implementation gate and was frozen immediately; no optional refinement round
was consumed. There are no known open P0, P1, or P2 implementation findings.
Eligible future feature expansion belongs to later owning phases.

The user-directed post-phase review waiver applies to this P01 closeout only.
Pre-phase requirements, architecture, and adversarial analyses remain in
`docs/reviews/P01/`.

## Next State

The evidence-only closeout checkpoint records the immutable candidate and
tree, closes P01, and advances the queue to P02 pre-phase analysis and source
admission. No optional P01 refinement or additional review pass follows.
