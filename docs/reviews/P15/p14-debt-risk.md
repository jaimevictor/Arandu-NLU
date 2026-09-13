# P14 Debt Risk Review Carried By P15

- Role: `risk`
- Analysis instance: `01a08cab-de62-7341-9814-c8e9f4f46645`
- Review date: `2026-09-10`
- Subject commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Subject tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Authorized parent: `aeac316eafa065b8c36fece92afa9c6b333c2eea`
- Mode: read-only
- Verdict: `FAIL`

## Findings

### P0 — Restart marker is not durable before effect dispatch

`custom_components/local_nlu/__init__.py` lines 156-165 treat a successful
`hass.config_entries.async_update_entry` call and the resulting in-memory
`entry.data` value as durable persistence. In pinned Home Assistant 2026.8.3,
`homeassistant/config_entries.py` lines 2658-2670 schedule the save, and lines
2891-2893 use delayed storage. An abrupt crash before that delayed save can
therefore lose the marker.

The reviewer counterexample produced:

```text
first_prepare dispatch
durable_marker False
after_crash_barrier False
second_prepare dispatch
```

The same effect can be dispatched again after restart without reconciliation.

### P1 — Exact-subject acceptance remains incomplete

`docs/evidence/P14-VALIDATION.md` lines 49-73 records that the exhaustive
governance mutation suite, exact-subject gate, and six mandatory reviews were
not completed. The subject remains a preflight baseline rather than a
minimally accepted P14 checkpoint.

### P1 — Native and real-runtime gates remain transferred

Native Linux process isolation and real Home Assistant lifecycle and security
behavior remain unexecuted and transferred to P15. Both release architectures
and artifact production correctly remain disabled.

## Focused Verification

The reviewer ran:

```text
python3 -B -S -m unittest -v test_ledger test_execution test_setup_lifecycle
```

All 56 selected tests passed. Their config-entry fake updates only memory, so
they do not cover the delayed-durability counterexample.

## Disposition

P15 implementation may proceed only while preserving the debt and disabled
artifacts. P15 acceptance and FINAL remain blocked until the P0 finding and
the transferred gates are closed under valid phase authority.

FAIL
