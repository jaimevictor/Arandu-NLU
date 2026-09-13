# ADR-0008: Deterministic and reproducible envelopes

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P01, P03-P16

## Context

Core outputs can be deterministic while sessions expire, Home Assistant state
changes, benchmark samples vary, and OCI archives include timestamps. Treating
all of these as one determinism claim would be false.

## Decision

Four envelopes are tested and reported separately.

### Semantic envelope

The same binary, configuration, language package, catalog snapshot revision,
session snapshot, injected logical time, and request bytes produce the same
core value and serialized bytes. Core code cannot read wall time, locale,
timezone, environment, filesystem order, network, entropy, or global mutable
state. Session expiry and ID creation use injected traits and explicit inputs.

### Adapter envelope

Given the same validated plan, policy, catalog generation, Home Assistant API
transcript, pairing-key epoch, authenticated channel transcript, caller
context, idempotency state, injected monotonic time, deadlines, and explicit
scheduling, cancellation, timeout, and reconnect events, the add-on adapter and
companion integration issue the same ordered request sequence and typed result.
Nonces and credential generation are explicit injected security inputs, not
semantic randomness. Live Home Assistant outcomes are external facts supplied
as explicit in-memory transcript inputs, not claimed deterministic.
"Transcript" here is a test/model input, not permission to persist, log, or
export residential values.

### Build envelope

Locked source, tools, dependencies, data, build arguments, target, and
`SOURCE_DATE_EPOCH` produce byte-identical architecture-specific artifacts in
clean directories. Paths, archive order, ownership, locale, timezone, and OCI
timestamps are normalized. Different architectures are compared only to their
own target baseline.

### Measurement envelope

Performance is statistically repeatable, not byte-deterministic. Reports pin
hardware and software, isolate cores when possible, define warmup and sample
counts, retain raw measurements, and publish spread plus quantiles.

## Required tests

- repeated semantic execution and serialization;
- locale, timezone, working-directory, path, and insertion-order variations;
- controlled logical-time expiry and replay;
- deterministic concurrency/model-checking schedules for stateful components;
- repeated add-on-adapter and companion executions from identical explicit
  authenticated transcripts;
- two clean offline builds in distinct absolute directories;
- per-architecture archive and image digest comparison;
- benchmark repetition with raw sample retention.

## Alternatives

1. Promise identical output while reading live Home Assistant state. Rejected
   because the input state is incomplete.
2. Exclude sessions and packaging from determinism. Rejected because both are
   release-critical.
3. Require identical benchmark timings. Rejected because scheduling and
   hardware noise make the requirement meaningless.

## Consequences

- Time, state, catalog generation, and randomness become explicit dependencies.
- Reproducibility failures can be assigned to the correct envelope.
- Release claims must name their envelope and inputs.

## Rollback

No envelope may be weakened. An implementation that cannot satisfy one must be
replaced or explicitly removed from release scope.
