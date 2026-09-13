# P15 Reproduction Of Inherited P14 Safety Debt

- Date: `2026-09-10`
- P14 subject commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- P14 subject tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Home Assistant tag: `2026.8.3`
- Home Assistant commit: `759e4658f40b3ccb671d418b8a0ed95224bf4561`
- Home Assistant tree: `f4a72534bb33abf8b5d183910a0c134b968af2f8`
- Finding severity: `P0`
- Result: `REPRODUCED`

## Primary Evidence

The frozen P14 subject defines `persist_restart_reconciliation` in
`custom_components/local_nlu/__init__.py` lines 156-165. It calls
`hass.config_entries.async_update_entry` and returns success when the
in-memory `entry.data` value changed.

The pinned Home Assistant source mutates the in-memory entry and then calls
`_async_save_and_notify` in `homeassistant/config_entries.py` lines
2640-2659. That method schedules persistence at lines 2661-2670.
`_async_schedule_save` delegates to delayed storage at lines 2891-2893.
Consequently, the component callback cannot prove that the restart marker is
durable before `ExecutionSafetyState.prepare_effect` returns `DISPATCH`.

## Independent Counterexample

The executor ran the production `ExecutionSafetyState` from a clean checkout
of the exact P14 subject. The fixture modeled the pinned Home Assistant
contract by immediately changing entry memory while leaving durable storage
unchanged and queuing the save.

Observed output:

```text
first_prepare dispatch
entry_memory_marker True
durable_marker False
save_queued True
after_crash_barrier False
second_prepare dispatch
```

The first runtime accepted the in-memory marker and dispatched. Simulated
process loss discarded the queued save. A new runtime loaded the unchanged
durable marker, established no reconciliation barrier, and authorized a
second dispatch.

## Existing-Test Gap

`tests/p14_companion/test_setup_lifecycle.py` lines 55-68 defines
`FixtureTecnicaConfigEntries.async_update_entry` as an immediate assignment.
The current suite checks callback failure and in-memory mutation, but does not
model delayed durable storage or crash-before-save.

## Release Consequence

The finding violates the pre-effect durability and no-blind-retry safety
contract. P14 has exhausted its authorized correction budget, and
`docs/evidence/P15-EVALUATION-ACCESS.md` freezes all companion production
behavior after held-out access. The executor therefore cannot silently patch
the finding in P15 or claim P15, P16, FINAL, artifact enablement, or
`DEVELOPMENT_COMPLETE`.
