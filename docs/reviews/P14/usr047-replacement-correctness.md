# P14 USR-047 Replacement Correctness Review

- Role: `correctness`
- Review instance: `01a08fb6-4a24-7042-b469-b6890b733733`
- Subject commit: `ba739823ffa7d55abc9042a62f4d5241108d1c49`
- Subject tree: `50a695d7cd0d81522d8d468fb0446fb857fee5df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

The reviewer ran four isolated inline Python schedules with
`PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=tests/p14_companion
/usr/bin/python3 -B -`, verified pinned Home Assistant commit
`759e4658f40b3ccb671d418b8a0ed95224bf4561` and tree
`f4a72534bb33abf8b5d183910a0c134b968af2f8`, and independently ran all
199 companion tests.

Reproduced results:

```text
crash_window_record=required=False,binding=None
next_process_unknown_barrier=False
durable_after_success=False,binding_present=True
fresh_reauth_setup_results=False,False
platform_loaded=True
platform_unload_calls=0
runtime_closed=True
platform_already_removed=True
cancellation_propagated=True
helper_revocations=0
```

The schedules respectively paused certificate consumption after the durable
write, restarted with state/endpoint drift, stopped after platform
publication, and cancelled platform unload after Home Assistant removal.
`sha256sum` and `cmp -s` independently reproduced the exact gate transcript
identity.

- P0: `P14-R5-01`.
- P1: none.
- P2: `P14-R5-07`, `P14-R5-08`, `P14-R5-09`.
- P3: none.

`FAIL`
