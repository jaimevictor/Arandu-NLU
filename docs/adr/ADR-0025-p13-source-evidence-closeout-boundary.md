# ADR-0025: P13 source-evidence closeout boundary

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0022 for fixture count and Poly1305 projection description;
  ADR-0023 for Linux file-reachability claims; ADR-0024 for origin vocabulary

## Context

Independent review of the `USR-024` candidate passed provenance and technical
quality but reproduced five bounded evidence defects: no versioned clean
acquisition recipe, one omitted Curve25519 test-vector origin statement,
stale fixture and Poly1305 counts, Git reads capable of lazy fetch, and a
Cargo command window in which a same-user process could transiently replace
validated bytes or configuration and restore them before endpoint hashing.

The review also distinguished exact Linux package graphs from native Linux
file reachability. P13 has no admitted Linux standard library or native Linux
build environment. Claiming that its static 192-file archive projection was
independently proven to be the exact Linux compile union exceeded the evidence.

## Decision

P13 makes one blocker-only closeout correction:

- bind a versioned acquisition and offline-replay recipe to the exact 23 crate
  archives, five supporting Git source families, the removed Cacophony source,
  and the standalone Creative Commons legal code;
- run every Git object read with `GIT_NO_LAZY_FETCH=1` and
  `GIT_TERMINAL_PROMPT=0`;
- expand the bounded origin vocabulary to include `derived from`, `ported
  from`, `extracted from`, `taken from`, `borrowed from`, and `inspired by`;
- bind Curve25519's retained `Test vectors extracted from ristretto.sage`
  statement and exact deleted same-package source to the retained BSD grant;
- state the exact lock closure as 23 external packages, 22 project-authored
  resolver fixtures, and one probe;
- state the Poly1305 projection as six files, excluding its README;
- invoke Cargo from `/` with one explicit evidence-bound config and manifest,
  a sealed Cargo home containing only that config, and no mutable ancestor
  configuration discovery;
- bind device, inode, mode, owner, group, link count, size, and nanosecond
  change time for every private source path before Cargo and after every
  command, so an unprivileged transient substitution causes the gate to fail
  even if bytes and modes are restored; and
- describe the 192 archive files plus two notices as the exact admitted P13
  projection and a conservative intended-Linux source set, not as a
  native-Linux-proven exact compile union.

P13's macOS capability validation assumes the selected host and user account
are not controlled by a privileged attacker. It does not claim kernel-enforced
read-only build isolation against root, the kernel, or a hostile hypervisor.
P14 must build both Linux targets from a kernel-enforced read-only source
snapshot, derive target file reachability from those builds, and fail before
product admission if the P13 projection is incomplete.

The broader origin matcher is an admission vocabulary for this immutable
projection, not a universal natural-language theorem. Independent review must
inspect the current bytes and may add a blocker only for a concrete omitted
current statement. Future source changes require a fresh complete scan.

## Consequences

P13 gains reproducible source acquisition, offline object closure, a complete
current origin disposition, and tamper-evident Cargo inputs without pretending
that a macOS package-graph check is a native Linux build. Product runtime,
packaging, and native Linux source admission remain disabled until P14.

This is the minimum blocker correction authorized by `USR-025`. It adds no
transport feature, package identity, compiled source, product behavior,
linguistic input, or optional refinement.

## Rollback

Keep the companion channel disabled and retain the credential-free local API.
Do not admit a product build that lacks native Linux read-only-snapshot
evidence or that expands the frozen source projection without a newer ADR and
source review.
