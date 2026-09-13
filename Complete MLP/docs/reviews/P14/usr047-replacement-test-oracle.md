# P14 USR-047 Replacement Test-Oracle Review

- Role: `test-oracle`
- Review instance: `01a08fb6-6a90-7171-b06a-3c49dff91909`
- Subject commit: `ba739823ffa7d55abc9042a62f4d5241108d1c49`
- Subject tree: `50a695d7cd0d81522d8d468fb0446fb857fee5df`
- Mode: independent read-only mutation review
- Verdict: `FAIL`

Three in-memory mutants were run under isolated CPython 3.9.6:

- a snapshot implementation that omitted state whenever a supported target
  remained disabled, unexposed, or service-unavailable;
- `RestartJournal.async_release_owner` replaced with an async no-op; and
- successful governance, Noise, and Home Assistant child output with an
  unrelated `FIXTURE_TECNICA_DIAGNOSTIC` line.

Commands used `env HOME=/private/tmp TMPDIR=/private/tmp LANG=C LC_ALL=C
TZ=UTC ... /usr/bin/python3 -I -S -B -c '<mutant>'` and
`/usr/bin/ruby --disable-gems -e '<subgate output mutant>'`.

Results:

```text
ha_runtime_with_snapshot_omission tests=6 success=True
setup_lifecycle_with_no_release tests=46 success=True
release_mutant_with_required_claim_fails=True
governance_hostile_accepted=true
noise_hostile_accepted_count=23
ha_hostile_accepted=true hostile_reemitted=true
```

The reviewer also reproduced the exact 199-test identity set and digest
`d11429c5ab86508a1a8208382220573c4ad0956623c5989e9c51aed519b24d7d`,
ran all 199 tests with zero skips/failures/errors, ran
`tools/test-validate-p14`, and verified a clean worktree.

- P0: none.
- P1: `P14-R5-04`.
- P2: `P14-R5-05`, `P14-R5-06`.
- P3: none.

`FAIL`
