# ADR-0032: Bounded P13 Archive And Copied-Source Closure

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-30
- Owners: P13-P14
- Supersedes: ADR-0031 only for the terminal P13 evidence correction

## Context

Mandatory review of P13 subject
`6a1851851091e6f3f0efd7e015331a15bfe86277` reproduced three bounded
source-evidence defects. Selected Rust archive members were size-bounded only
after extraction. Registry packages were content-scanned, but selected Rust
path-package roots were not. Two detected copied-source statements had only
generic package dispositions: pulldown-cmark's Redwood-derived utility lacked
the exact author relicensing grant, and tracing-subscriber's copied Hyperium
region lacked an exact dual-license origin binding.

These findings do not justify another transport selection or product change.

## Decision

Before writing any selected Rust archive member, validation MUST list the held,
already hash-verified archive descriptor and reject unexpected types, paths,
links, counts, depth, per-file sizes, or aggregate bytes. The same descriptor
MUST remain bound across preflight and extraction. Post-extraction path, type,
size, checksum, and aggregate checks remain mandatory.

P13 MUST conservatively scan the selected compiler, Clippy, and sysroot source
roots, excluding registry vendor roots already scanned separately. Evidence
MUST bind aggregate entry and file inventories, the two known Clippy license
symlinks, every bounded legal or origin witness, and an allowlisted semantic
disposition. CC0 Unicode test data MUST be classified as non-software data, not
as an admitted software license. Native file reachability remains a P14
read-only Linux build obligation.

Pulldown-cmark `0.11.3` `src/utils.rs` MUST be bound to its exact package
checksum and Git blob, the exact Redwood source blob and GPL-3.0-only license,
the exact copied region, and Benjamin Richner's immutable permission to use,
modify, redistribute, and relicense that exact source. P13 elects MIT for that
copy. Tracing-subscriber `0.3.20` `src/registry/extensions.rs` MUST be bound to
the exact Hyperium HTTP source region and its MIT OR Apache-2.0 grants; P13
elects MIT.

## Minimum Acceptance And Pass Limit

This is the blocker-only correction authorized by `USR-035`. Focused
regressions and the full non-Cargo P13 gates MUST pass one immutable subject.
All mandatory source and phase reviewers MUST review that same subject and
report no open P0 through P2 finding. The first passing subject checkpoints
immediately. No optional final review or refinement pass is permitted.

## Consequences

P13 gains bounded pre-extraction evidence and exact copied-source rights
bindings. It gains no product feature, source portfolio, dependency, protocol,
cryptographic, or linguistic change. P14 still owns native amd64 and aarch64
Linux builds from kernel-enforced read-only sources and runtime admission.

## Rollback

Keep the transport candidate disabled and record P13 blocked if this one
replacement cannot pass its mandatory same-subject gates.
