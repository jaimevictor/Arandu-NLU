# ADR-0039: P14 host validation boundary

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-01
- Owners: P14-P15

## Context

P14 requires native Linux amd64 and aarch64 build and execution from a
kernel-enforced read-only source snapshot. The available executor is macOS
arm64 and has no admitted Linux container, virtual-machine, or emulator
runtime. Installing an unreviewed runtime or guest image would violate the
project's FOSS source-admission boundary.

The user directed the executor to keep P13 closed, compromise where necessary,
finish the current work immediately, and move on without optional refinement.
The transport source projection has replayed successfully, but that replay is
not native product admission.

## Decision

P14 validates the complete adapter, server, companion, Noise, Supervisor,
Wyoming, catalog, authorization, idempotency, and pinned Home Assistant
contracts on the admitted host toolchain. It records native Linux execution as
not performed and transfers that gate to P15, where architecture packaging is
already mandatory.

This transfer is fail-closed:

- `addon/build-contract.json` keeps both architectures disabled;
- artifact production and the container recipe remain prohibited;
- P14 source-promotion evidence remains pending native Linux admission;
- no native amd64 or aarch64 PASS is claimed; and
- P15 may enable an architecture only after its native read-only-source build,
  runtime, process-isolation, and rejected-source reachability checks pass.

P14 freezes the first otherwise passing candidate and runs only mandatory
same-subject reviews. The transfer does not authorize an optional P14
candidate or weaken the product's final release gate.

## Consequences

P14 can close without importing an unadmitted virtualization stack. P15 owns
both the deferred native gate and the existing install, upgrade, rollback,
reproducibility, and artifact-admission requirements. Until P15 passes, the
repository contains implementation source but no enabled distributable
add-on artifact.

## Rollback

If an admitted native executor becomes available before P14 freezes, run the
original P14 native gate and supersede this transfer. After P14 freezes, P15
closes the gate; it may not reinterpret host-only tests as native evidence.
