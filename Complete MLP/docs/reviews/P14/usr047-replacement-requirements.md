# P14 USR-047 Replacement Requirements Review

- Role: `requirements`
- Review instance: `01a08fb6-2c3e-71e0-9416-48535d294567`
- Subject commit: `ba739823ffa7d55abc9042a62f4d5241108d1c49`
- Subject tree: `50a695d7cd0d81522d8d468fb0446fb857fee5df`
- Mode: independent read-only primary-evidence review
- Verdict: `FAIL`

The reviewer verified the exact clean subject, 12-path base-to-candidate
scope, disabled release artifacts, two byte-identical complete-gate
transcripts, and the 199-test companion suite.

Counterexample command:
`/usr/bin/python3 -I -S -B -c '<RestartJournal crash-window schedule>'`.
The input persisted a certificate for snapshot A, changed the live snapshot
to B immediately before the durable `false/null` write, and opened a new
journal at that crash point. It reproduced:

```text
validated=True
snapshot_changed=True
durable_required=False
durable_binding=None
after_crash_unknown=False
after_crash_pending=False
```

Transcript checks used `shasum -a 256`, `wc -l -c`, and `cmp -l` on
`/private/tmp/nlu-p14-gate-ba73982-run1.txt` and `run2.txt`; both were 246
lines, 21,209 bytes, and SHA-256
`bf53eb0e10e4054d069913022050bf74efa353fa0b5c3cd51180dec3279d57e4`.

- P0: `P14-R5-01`.
- P1: none.
- P2: none.
- P3: none.

`FAIL`
