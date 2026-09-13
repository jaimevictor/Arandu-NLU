# ADR-0040: P14 real Home Assistant runtime transfer

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-01
- Owners: P14-P15

## Context

P14 requires execution against Home Assistant 2026.8.3 and the latest stable
release. On 2026-09-01 the latest-release endpoint resolved to 2026.8.3, tag
commit `759e4658f40b3ccb671d418b8a0ed95224bf4561` and tree
`f4a72534bb33abf8b5d183910a0c134b968af2f8`.

The available Home Assistant virtual environment is not admissible. It uses
the permanently rejected Homebrew CPython 3.14.6 runtime from ADR-0021 and
contains 105 installed package distributions whose complete source and
license closure has not been reviewed. Executing that environment would turn
rejected and unknown-provenance bytes into a project validation dependency.
The host's CPython 3.9.6 can run the dependency-free companion contract suite,
but Home Assistant 2026.8.3 requires a newer Python and cannot run there.

## Decision

P14 freezes and validates the exact Home Assistant source and latest-stable
identity, but does not execute the unadmitted virtual environment and does not
claim that the real Home Assistant tests passed.

P15 receives the real-runtime gate together with its existing clean install,
upgrade, rollback, package, and architecture gates. Before any artifact or
architecture is enabled, P15 must:

- admit one complete FOSS Python runtime and Home Assistant dependency closure;
- execute the pinned and latest-stable integration suites in a clean Home
  Assistant instance;
- prove install, restart, re-pair, upgrade, rollback, and removal behavior; and
- retain the native Linux transfer from ADR-0039.

The transfer remains fail closed. Both add-on architectures and artifact
production stay disabled, the P14 gate prints an explicit transfer marker, and
`P14-HA-009`, `P14-HA-010`, `P14-GATE-001`, and their real-runtime dependents
remain unsatisfied until P15 evidence closes them.

## Consequences

P14 can close the adapter and companion implementation without laundering a
rejected runtime into validation evidence. P15 has one combined admission and
installation boundary rather than two partial runtime environments. No real
Home Assistant PASS is recorded in P14.

## Rollback

If a completely admitted Home Assistant runtime becomes available before the
P14 subject is frozen, execute the original P14 suites and supersede this
transfer. After freeze, P15 owns the gate.
