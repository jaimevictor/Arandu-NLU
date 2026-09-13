# P14 Final Runtime-Adversarial Review

- Role: `runtime-adversarial`
- Review instance: `01a087a8-2ec9-7a10-a09a-7b005a0f60bb`
- Subject commit: `e2ab301bad38caeaa2f32664bf442501eb8804df`
- Subject tree: `a5b7e7958304040ae72932f6d9dd1e7800acce70`
- Comparison: `2c44119a1a2f3ddc77d08ceea3e504f1e3bbcd7f`
- Comparison tree: `2a2d6a8bd8e519388f2f2f86b6009097324343df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

## Scope And Commands

The reviewer exercised lifecycle and concurrency schedules covering stop,
close, epoch rotation, delayed helper replies, reconciliation, sequential
authorization, exact TTL boundaries, logical-clock failures, capacity,
helper cleanup, and caller isolation.

The complete 132-test companion suite passed under local socket permissions.
Inline dependency-free schedules reproduced both findings. Scheduler failure
otherwise erased typed sessions and returned `typed_session_time`; focused
checks supported stop revocation, TTL boundaries, child-exit-before-cleanup,
and `conversation_id=None` caller isolation. The exact subject remained
clean.

## Counterexamples

- Effect A completed at tick 1,000. An unrelated request rotated retention at
  tick 301,000. Replaying A as production-shaped `INITIAL` work at tick
  601,000 completed and increased service calls from one to two.
- A clarification reply for epoch A was paused. Epoch B activated before the
  reply was released. The runtime accepted the delayed reply, created typed
  continuation state, and later emitted `ContinueSubmission` for state born
  under the retired epoch.

## Findings

- P0: none.
- P1: Expired operation identity is redispatched as new work.
- P1: An old-epoch helper reply can create continuation state after epoch
  rotation.
- P2: none.
- P3: none.

`FAIL`
