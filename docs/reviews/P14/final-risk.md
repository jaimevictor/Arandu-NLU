# P14 Final Risk And Privacy Review

- Role: `risk`
- Review instance: `01a0879a-0a4c-7743-acf0-f6a5f35570ff`
- Subject commit: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Comparison tree: `2a2d6a8bd8e519388f2f2f86b6009097324343df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

## Scope And Commands

The reviewer inspected duplicate-effect containment, restart reconciliation,
authorization and epoch state, privacy retention, helper lifecycle, and
credential/residential sinks without consulting prior review conclusions.
All 132 companion tests passed. Focused subject-versus-parent Python schedules
and a local Unix-socket pre-proof timeout probe produced the counterexamples.
The worktree remained clean.

## Counterexamples

- Execute effect A, advance one TTL, execute effect B, advance another TTL,
  then resend A with a new nonce. The subject returned three completed
  results and dispatched targets `[A, B, A]`.
- Restore an unknown barrier concerning entity A while unrelated entity B
  already has its requested state. Reconciling B cleared the barrier, after
  which A dispatched without evidence about the unknown prior effect.
- A helper bound its private Unix endpoint and then timed out before proof.
  The child exited, but the socket and directory remained because no Python
  exchange object had been constructed.

## Findings

- P0: Expired production identities can repeat an external effect.
- P0: Unrelated live state can clear an unknown restart barrier.
- P2: Pre-proof helper failure can leave a private endpoint and directory.
- P3: none.

`FAIL`
