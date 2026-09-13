# ADR-0050: Minimum lovable product reset

- Status: `ACCEPTED`
- Date: 2026-09-12
- Owners: MLP
- Supersedes: ADR-0005 through ADR-0049 where they prescribe P00-P16 delivery,
  breadth, benchmark, cryptographic pairing, tribunal, or release mechanics

## Context

The repository reached roughly eighty thousand lines of Rust, ten thousand
lines of companion integration code, dozens of governance validators, and
repeated immutable six-review rounds without producing an installable add-on.
The review system repeatedly found real defects, but its own complexity also
created defects and exhausted its budgets. The user explicitly requested a
minimum lovable product without overengineering and continuous work through
final delivery.

The user then added command chaining, including both coordinated targets such
as `apaga a luz da sala e do quarto` and ordered mixed actions such as
`apague X e ligue Y`, plus fan speed control. Read-only sensor values are
desirable and share the state-query path.

## Decision

Deliver one complete vertical slice:

- A passive Rust add-on accepts a bounded JSON request containing an original
  PT-BR utterance and a current catalog snapshot.
- It returns `plan`, `ambiguous`, `no_match`, or `invalid_request`.
- A plan contains one through four ordered operations. Each operation is
  `turn_on`, `turn_off`, `set_fan_percentage`, or `get_state`.
- One operation may contain multiple sorted stable entity-registry IDs
  resolved from at most four exact entity or area clauses.
- Coordinated area ellipsis is supported for one domain, including
  `a luz da sala e do quarto`.
- Effects target `light`, `switch`, or `fan`; fan percentage is an integer from
  0 through 100. Read-only queries also support `sensor` and `binary_sensor`.
- The Home Assistant integration creates the snapshot, sends the request,
  resolves every registry ID again, verifies the complete plan's exposure,
  availability, domain, service support, non-contradiction, and caller
  permission before the first effect, then executes in spoken order or queries
  locally.
- There is no add-on Home Assistant credential, persistent catalog, pairing
  protocol, custom cryptography, session state, timer, graph executor,
  exactly-once ledger, or generic service passthrough.

Read-only queries remain standalone. Contradictory reuse of one target across
multiple effect operations abstains.

## Delivery

The old crates and phase evidence remain in Git history but are outside the
active workspace and release package. The active implementation is one Rust
crate plus one small companion integration.

The MLP uses one fast standard gate and two focused read-only reviews. It does
not use frozen-candidate budgets, six-role tribunals, self-hashing transcript
validators, native dual-architecture qualification, or a terminal guard.
Container images may be built by Home Assistant from the supplied add-on
recipe; this repository delivers source and package structure rather than
claiming prebuilt architecture artifacts.

## Consequences

The MLP intentionally has narrow language and device coverage. Exact matching
and abstention trade breadth for predictable safety. Future features require a
real user need, a small contract extension, and tests; they do not revive the
retired phase machinery.
