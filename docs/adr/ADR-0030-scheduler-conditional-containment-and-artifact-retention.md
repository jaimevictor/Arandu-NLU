# ADR-0030: Scheduler-Conditional Containment And Artifact Retention

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0029 for cleanup behavior and deadline claim scope

## Context

Mandatory review of P13 subject
`30329e2524dd86e0e30933cc9d780c341f95858e`
reproduced bounded defects in exact-source replay and server containment:
verified archives were reopened by path, Git could lazy-fetch missing objects,
cleanup could delete a same-name replacement, and derived tar work was unbounded.
Release used `panic = "abort"`, preventing the worker
retirement guard from observing a handler panic. Review also showed that no
independent in-process monitor can run while every thread in its process is not
scheduled.

Rust cannot revoke arbitrary handler memory access from another thread in the
same process. A scheduler-independent hard deadline therefore needs a stronger
OS boundary. Adding an external supervisor script, a new dependency, or broad
unsafe FFI is outside the minimum authorized P13 correction.

## Decision

### Verified Source And Bounded Replay

Validators MUST parse the exact byte strings returned by hash verification.
All Git-capable subprocesses MUST set `GIT_NO_LAZY_FETCH=1`.
Source fetch and extraction MUST revalidate the terminal published name and
then perform no further path-dependent success step.
Cleanup MUST use atomic no-clobber rename into a retained quarantine before
checking identity; it MUST NOT delete the quarantined entry. Archive parsing
MUST bound path depth and all explicit or derived manifest entries.

### Release Panic And Deadline Semantics

The workspace release panic strategy MUST be `unwind`.
A handler panic can then retire its worker, and the scheduled monitor requests
code 70 process exit without a core-dump abort path.

Request and shutdown deadlines remain checked monotonic application
deadlines. A queued request never enters a handler after observed expiry, and
when scheduled the monitor exits on an overdue admitted request or stuck join.
P13 makes no scheduler-independent claim about process-termination latency or a
wall-clock maximum while the operating system does not schedule the process.

### Socket Retention

The server process MUST NOT remove or rename its published Unix-domain
socket path during drop, panic, timeout, or fatal exit. The socket remains in a
private process-generation directory after the listener closes. P14 MUST use a
fresh private directory for every server generation and MUST NOT reuse a stale
socket path. Test code MAY remove a fixture socket only after the child has
stopped and all server references have been dropped.

The retained socket inode carries no credentials, utterance, or residential
state and becomes unreachable when its runtime filesystem generation retires.

## Minimum Acceptance And Pass Limit

This is the blocker-only correction authorized by `USR-033`. Exact
verified-byte consumption, lazy-fetch denial, terminal-name substitution,
atomic quarantine retention, derived-entry and path-depth limits,
release-panic unwinding, scheduled fatal containment, race-free socket
retention, existing source/runtime tests, and validator mutations must pass.
One immutable replacement receives only mandatory reviews; the first PASS
checkpoints immediately, with no optional review or refinement.

## Consequences

P13 now states only guarantees its implementation and OS boundary can support.
Availability still depends on ordinary process scheduling.
Fresh generation directories trade bounded stale filesystem names for safety.
No selected source, dependency identity, protocol, or linguistic input changes.

## Rollback

Keep the server disabled if P14 cannot allocate fresh private generations or if
scheduling assumptions and retained runtime paths are unacceptable.
