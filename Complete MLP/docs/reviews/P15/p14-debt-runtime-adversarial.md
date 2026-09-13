# P14 Debt Runtime-Adversarial Review Carried By P15

- Role: `runtime-adversarial`
- Analysis instance: `01a08cb1-96f8-72b0-9c6b-5fe856c62d27`
- Review date: `2026-09-10`
- Subject commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Subject tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Authorized parent: `aeac316eafa065b8c36fece92afa9c6b333c2eea`
- Mode: independent, read-only
- Verdict: `FAIL`

## P0 — Restart Marker Is Acknowledged Before Durable Storage

`custom_components/local_nlu/__init__.py` lines 156-165 treats
`async_update_entry` and an in-memory data check as persistence. Pinned Home
Assistant 2026.8.3 instead schedules storage after a one-second delay:

- `homeassistant/config_entries.py` lines 2640-2670;
- `homeassistant/config_entries.py` lines 2891-2893; and
- `SAVE_DELAY = 1` at line 137.

`custom_components/local_nlu/ledger.py` lines 461-465 and 671-683 can
therefore authorize dispatch before the restart barrier reaches durable
storage.

The abrupt-crash probe observed:

```text
FIRST ('new', 'dispatch', True) durable_marker False
AFTER_CRASH ('new', 'dispatch', True) durable_marker False
```

The same physical effect can dispatch again after restart and re-pair.

## P1 — Failed Helper Startup Loses Process Ownership

`custom_components/local_nlu/helper_process.py` lines 243-254 counts only
`_records`. After credential delivery at lines 399-408, startup failure
removes the record before termination success is known at lines 430-468.
After `_forget_future` at lines 553-558, shutdown at lines 291-349 cannot
recover a child when `_terminate_and_wait` returns false at lines 805-821.

Three valid fixture provisions against a capacity of two produced:

```text
MAX_LIVE_HELPERS 2
PROVISIONS_ACCEPTED 3
BEFORE_SHUTDOWN records futures alive endpoints (0, 0, 3, 3)
AFTER_SHUTDOWN records futures alive endpoints (0, 0, 3, 3)
CREDENTIAL_DELIVERY [True, True, True]
SIGNALS [(True, True, 2), (True, True, 2), (True, True, 2)]
```

Existing tests cover non-exit and live-record capacity separately, but not
the combined schedule.

## Reproduced Checks

The exact subject identity and clean clone checks passed. Ninety focused
Python runtime and helper tests, fourteen add-on helper-relay and IPC tests,
and eleven NLU-server runtime-contract tests passed. No additional P0 through
P2 issue was found in replay, epoch, cancellation, or typed-relay paths.

Native Linux amd64 and aarch64 and real Home Assistant execution remain
transferred and unexecuted; artifacts and both architectures remain disabled.

FAIL
