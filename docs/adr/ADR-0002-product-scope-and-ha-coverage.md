# ADR-0002: Product scope and Home Assistant coverage

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-24
- Owners: P00, P09-P15

## Context

The product is a PT-BR home-automation NLU delivered as a Home Assistant
app/add-on. The desired domain coverage is "ideally all" Home Assistant
domains, but Home Assistant domains and services evolve and not every service
has safe, typed voice semantics.

## Decision

The core converts text into exactly one of four outcomes: a typed plan,
clarification, abstention, or protocol error. It never executes a service.

The release target is a locally installable Home Assistant app/add-on. A
separate supervisor script is out of scope. The integration design will support
Home Assistant's current public contracts and may expose a Wyoming endpoint,
but the `ha-adapter` subsystem remains the only Home Assistant access boundary.
That subsystem has two explicit parts: the add-on adapter process may hold the
Supervisor token for catalog synchronization, while the companion integration
inside Home Assistant may receive caller `Context` and invoke revalidated typed
operations. Core, language, policy, protocol, renderer, and server components
hold neither authority.

"All domains" is implemented as measurable catalog breadth, not arbitrary
service invocation:

1. Catalog ingestion preserves every exposed entity's stable ID, domain,
   capabilities, area, floor, device, aliases, and snapshot generation.
2. Resolution and state-query planning are domain-extensible.
3. Actions require an explicit typed operation schema, capability check, risk
   policy, and adapter mapping.
4. Official built-in Home Assistant intent families form the minimum release
   coverage. Additional domains are enabled through reviewed capability
   descriptors rather than code paths that accept arbitrary service names.
5. Every release emits a machine-readable coverage report by domain, operation,
   and capability.
6. An unknown domain, service, capability, or stale schema produces
   clarification or abstention. It never falls through to a generic call.

Sensitive operations such as unlocking, opening access control, disabling
alarms, or safety-affecting device control require explicit policy and
confirmation even when linguistically unambiguous.

## Alternatives

1. Hard-code a fixed enum of current domains. Rejected because it silently
   falls behind Home Assistant and makes "all domains" unmeasurable.
2. Accept arbitrary `domain.service` strings in plans. Rejected because it
   collapses interpretation and execution and permits unsafe calls.
3. Delegate recognition and execution to Home Assistant's conversation API.
   Rejected because it does not satisfy the independent deterministic engine or
   separated execution boundary.

## Consequences

- New domains can be cataloged without a core release, but actionable support
  still requires a reviewed typed schema and policy.
- Domain coverage can be broad while action coverage remains explicitly
  partial and fail-closed.
- Integration tests need faithful Home Assistant catalog and API mocks.

## Rollback

Capability descriptors may be disabled or narrowed without changing core
types. Transport and packaging decisions remain replaceable behind the adapter.
