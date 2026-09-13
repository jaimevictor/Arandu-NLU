# P14 Final Correctness Review

- Role: `correctness`
- Review instance: `01a08799-eca5-7431-8963-c559effeceaa`
- Subject commit: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Comparison tree: `2a2d6a8bd8e519388f2f2f86b6009097324343df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

## Scope And Commands

The reviewer inspected operation and session retention, effect
reconciliation, runtime replacement, clock behavior, capacity, malformed
input, helper cleanup, and continuation routing without using prior review
conclusions.

The focused ledger, execution, runtime, helper, helper-process, and setup
lifecycle suite passed 95 tests under admitted CPython 3.9.6. Custom
dependency-free probes reproduced the findings below. Stop-time revocation,
post-child-exit cleanup, malformed input, and `conversation_id=None`
continuation passed their focused checks. The exact subject remained clean.

## Counterexamples

- After two retention cohorts, replaying an old operation as `INITIAL`
  completed and increased service calls from one to two. An old session ID
  was likewise accepted as fresh work.
- A two-effect operation retained only its final effect evidence. Reconciling
  that evidence cleared the barrier and allowed the earlier effect to run
  again.
- An unrelated already-satisfied operation cleared an evidence-free restart
  barrier and allowed an unresolved effect to dispatch.
- A `1000 -> 999` logical-time sequence crossed independent samplers and
  completed an external effect; a clock exception also escaped as a raw
  runtime error.
- A mismatching reconciliation denial was cached, so the stable operation ID
  could not recover after live state later matched.
- A reconciliation probe exceeded configured shared-state capacity, while a
  capacity-two sequence could consume the remaining slot before recovery.

## Findings

- P0: none.
- P1: Expired identities can become fresh effectful work.
- P1: Single-valued evidence cannot reconcile a multi-effect operation
  exactly, and unrelated state can clear an unknown barrier.
- P1: Independently sampled logical clocks do not fail closed globally.
- P2: Mismatch reconciliation cannot recover with the stable operation ID.
- P2: Reconciliation can exceed or deadlock at configured capacity.
- P3: none.

`FAIL`
