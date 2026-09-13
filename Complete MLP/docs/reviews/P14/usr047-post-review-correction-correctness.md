# P14 USR-047 Post-Review Correction Correctness Review

- Role: `correctness`
- Review instance: `01a0916d-6564-7af1-9592-44c9196072c1`
- Subject commit: `f919aba0defb9c1d2bb773c7eef2b44071ccb17f`
- Subject tree: `d6bef59bc8ba9785ca6c245e014f1d8bf37d6388`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

The reviewer verified the exact clean subject and eight-path correction,
replayed eleven focused regressions, passed all 199 companion tests, and
passed the validator self-tests.

Malformed persisted metadata makes `async_remove_entry` return before
unresolved-effect orphan bookkeeping. The reproduced schedule completed an
effect, unloaded the old entry, replaced its metadata with an empty mapping,
removed it, and paired a distinct entry. The decisive output was:

```text
orphaned_after_malformed_remove []
journal_required True
second_unknown_barrier False
second_effect_preparation dispatch
```

Failed platform forwarding also begins platform unload before revoking
runtime dispatch. With unload paused, an actual companion runtime completed
one service call:

```text
platform_published_during_rollback True
runtime_closed_during_rollback False
effect_result_during_rollback completed completed
service_calls_during_rollback 1
setup_result False
```

- P0: `P14-R6-01`.
- P1: `P14-R6-03`.
- P2: none.
- P3: none.

`FAIL`
