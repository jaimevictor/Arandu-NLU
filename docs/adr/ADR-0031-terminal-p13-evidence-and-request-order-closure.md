# ADR-0031: Terminal P13 Evidence And Request-Order Closure

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-30
- Owners: P13-P14
- Supersedes: ADR-0030 only for the final P13 blocker correction

## Context

Mandatory review of P13 subject
`e04abd50fbd8f598068d975914e4a59787e71839`
reproduced seven bounded defects. Closeout Git subprocesses did not all disable
lazy fetch. Existing exact extractions could have their terminal name replaced
after the last parent check. The archive-depth limit lacked an exact boundary
regression. An expired active request could become monitor-invisible before
fatal exit. Concurrent requests could sample increasing clock ticks but
dispatch them in decreasing order. Rust registry legal discovery relied on
filenames despite coherent legal grants being possible under other names.
Selected Rust toolchain source-origin statements outside classified legal files
had no complete disposition.

These are reproduced safety and evidence blockers, not a reason to reopen the
transport portfolio or add behavior.

## Decision

### Exact Source And Rights Evidence

Every closeout Git subprocess MUST set `GIT_NO_LAZY_FETCH=1`.
An accepted existing extraction MUST revalidate its terminal directory identity
after the final parent-identity check. The exact maximum archive path depth and
the first rejected depth MUST both be tested with valid USTAR paths.

Registry legal discovery MUST combine conventional-name classification with
bounded content detection. A coherent restrictive or permissive grant under an
unrecognized filename MUST enter the reviewed inventory or fail closed.
Every detected origin statement in selected Rust toolchain source, including
statements outside conventional legal files, MUST have an exact evidence
disposition. Package-lock reachability MUST NOT be represented as target source
reachability; P14 retains native Linux reachability admission.

### Request Lifetime And Ordering

An admitted request that expires MUST remain represented by a monitor-fatal
state until the dedicated process exits. Failed completion MUST NOT clear that
state.

Clock sampling and stateful runtime dispatch MUST occur under one request-order
critical section. Increasing samples therefore cannot reach runtime state in
decreasing order. A genuine sequential clock rollback remains fail-closed and
purges pending state.

## Minimum Acceptance And Pass Limit

This is the blocker-only correction authorized by `USR-034`. Each reproduced
counterexample requires an exact regression. Focused suites, the full P13
mutation and aggregate gates, five independent source reviews, and all mandatory
phase reviews must pass one immutable subject with no open P0 through P2
finding. That first passing subject checkpoints immediately. There is no
optional final review or refinement pass.

## Consequences

P13 gains no feature, source portfolio, dependency, protocol, cryptographic, or
linguistic change. Request handling becomes intentionally serialized at the
stateful runtime boundary. P14 still owns native Linux source reachability,
runtime transport admission, and packaging.

## Rollback

Keep the transport runtime disabled and record P13 blocked if this one bounded
replacement cannot pass the mandatory same-subject gates.
