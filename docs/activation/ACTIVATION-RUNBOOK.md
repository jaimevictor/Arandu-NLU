# Arandu NLU v2 — Activation Runbook (controlled pilot)

Status: preparation only. v2 ships disabled (`v2_enabled: false`,
`shadow_enabled: false`). Nothing here activates anything by itself.
No step executes a device without passing the full preflight chain.

## 0. Pre-activation operational checklist

All must hold (re-run, do not trust transcripts):

- [ ] `cargo fmt --all -- --check` clean
- [ ] `cargo clippy --workspace --all-targets --locked --offline -- -D warnings` clean
- [ ] `cargo test --workspace --all-targets --locked --offline` green (80 tests)
- [ ] `python3 -m unittest discover -s tests/mlp` green (58 tests)
- [ ] `evaluation/ptbr-independent/{entity-resolution,mention-extraction,v2-interpret}/freeze.py --check` green
- [ ] `evaluation/ptbr-independent/regression_gate.py --binary target/release/local-nlu.exe` → 144/144 + 23/23
- [ ] `tools/check-mlp-package.py` except the Linux-vendor-tree step (fails on
  NTFS workstations for archive-mode reasons; unrelated to this change set)
- [ ] `engine-source-divergence.json` digest matches the built tree
- [ ] Release binaries rebuilt from current sources (`local-nlu.exe`,
  `er_bench.exe`, `mx_shadow.exe`); never trust `target/` timestamps alone
  (`cargo clean -p` does not remove final binaries here and hardlink twins
  confuse freshness — delete the exes and rebuild when in doubt)

## 1. Installation (exact, verified in code)

Add-on (`addon/config.yaml`: slug `ptbr_nlu`, port `11555/tcp`, health
watchdog `http://[HOST]:[PORT:11555]/health`):

1. Copy the `addon/` directory to the Home Assistant host as a local
   add-on source and install it via Supervisor → Add-on Store (local
   section), or build the image from `addon/Dockerfile`.
2. Start it; verify `GET http://<host>:11555/health` returns
   `{"status":"ok","version":1}`.

Integration (`custom_components/local_nlu`, domain `local_nlu`,
`manifest.json`: `version 0.1.0`, `config_flow: true`,
`single_config_entry: true`, dependency `conversation`):

1. Copy `custom_components/local_nlu/` to `<ha-config>/custom_components/`.
2. Restart Home Assistant. Settings → Devices & Services → Add Integration
   → "Local NLU" (`strings.json` title). Single instance only
   (`single_instance_allowed` abort).
3. Endpoint form (`strings.json → config.step.user`): enter
   `http://local-ptbr-nlu:11555` (`const.DEFAULT_ENDPOINT`). The flow
   validates locality, performs `GET /health`, and aborts with
   `cannot_connect` on failure (`config_flow.py`).
4. Select "Local NLU" as conversation agent (pt-BR) to serve utterances.

## 2. Controlled real-test battery (DO NOT EXECUTE YET)

Run on an approved lab instance with manually authorized domains only.
Record outcome codes; persist no utterances. Kill-switch armed.
All drills use dedicated lab test entities and a dedicated non-admin
test user — never residential devices or the owner's account.

### 2.1 Lab parameters (fill per instance before running)

| Parameter | Meaning | Example |
|---|---|---|
| `LAB_LIGHT_DISPLAY` | Friendly name of the lab test light | `Luz da sala` |
| `LAB_LIGHT_ALIAS` | Explicit alias of the same light | `Luz principal` |
| `LAB_LIGHT_ENTITY_ID` | Dotted ID of the same light | `light.luz_sala` |
| `LAB_AREA` | Area of the test light | `sala` |
| `LAB_UNKNOWN_AREA` | Area name absent from the instance | `copa` |
| `LAB_TIE_DISPLAY` | Display shared by 2+ lab lights | `abajur` |
| `LAB_USER` | Dedicated non-admin test user | `nlu-tester` |
| `LAB_FAN_PCT` | Lab fan supporting percentage | `ventilador` (+50%) |

### 2.2 Command rows (templates; substitute parameters)

| # | Command template | Precondition | Expected |
|---|---|---|---|
| R1 | `Acenda o {ALIAS} da {AREA}.` | v2 opt-in; alias exposed | `success`, 1 call `light.turn_on` on the test light |
| R2 | `Acenda {ENTITY_ID}.` | v2 opt-in on | `success` (external-ID capability v1 lacks) |
| R3 | `Acenda o abajur da {UNKNOWN_AREA}.` | v2 opt-in on | `no_match`, zero calls (unlinked poisoning) |
| R4 | `Acenda o {TIE_DISPLAY}.` | v2 opt-in on | `ambiguous`, zero calls, generic rendering |
| R5 | `Apaga a luz da {AREA} e do quarto.` | v2 opt-in on | served by v1 (ellipsis pre-route), v2 untouched |
| R6 | `Qual é o estado do abajur?` | v2 opt-in on | served by v1 (query pre-route), v2 untouched |
| R7 | R1 with the test light renamed between two scripted requests | v2 opt-in on | second request `stale`, zero calls (deterministic: rename-then-request, no race needed — generation differs) |
| R8 | R1 with `LAB_USER` permissions revoked | v2 opt-in on | `denied`, zero calls |
| R9 | R1 with flag flipped off mid-flight | v2 opt-in on | completes terminally, no fallback; next request v1-only |
| R10 | R1 with both flags off after R1–R9 | flags off | byte-identical v1 behavior on scripted set (rollback drill) |

R7 note: renaming between requests deterministically flips the next
generation (descriptor change), which is exactly the production stale
path (rebuild → generation mismatch). Mid-flight races are covered
offline by mock tests; live, a bounded rename-loop variant (rename in a
loop while sending, cap 20 attempts) may be used to hit the in-flight
window — pass requires every attempt to end in `success` or `stale`
with zero wrong-target effects.

### 2.3 Differential comparison v1 × v2 (simple accepted commands)

For each simple single-effect command the lab v1 accepts (no ` e `,
non-query): run once with flags off (record v1 targets), once with v2
opt-in (record v2 targets + outcome). Compare target SETS only, per the
ADR-0053 taxonomy: equal sets (diagnostic agreement, never a plan
equivalence claim); v2-resolved where v1 abstains (expected for
external IDs — new capability, record separately); v1-plan where v2
abstains (expected for display-only singles — contract rule, record);
any other divergence is investigated individually and blocks pilot
approval until classified. Actions, ordering, and segmentation are
recorded as not-evaluated dimensions, explicitly.

## 3. Activation (opt-in only)

1. HA → Settings → Devices & Services → "Local NLU" → Configure.
   Options flow (`config_flow.LocalNluOptionsFlow`, step `init`) exposes
   two booleans (raw field names render until product copy lands in
   `strings.json`/`translations/`):
   - `v2_enabled` (default `false`): single-effect commands attempt v2.
   - `shadow_enabled` (default `false`): bounded observe-only probes
     (max 4 identity + 3 negative resolve calls per served request).
2. The runtime reads both options on every request
   (`LocalNluRuntime` provider callables wired in `__init__.py`); no
   restart needed. In-flight requests finish terminally; only new
   requests observe changed flags. Single interpretation call per
   utterance is structural (if/else dispatch).
3. Recommended order: enable `shadow_enabled` first (phase 0, observe
   aggregate debug counters), then `v2_enabled` (phase 1). Default flip
   (phase 2) requires separate approval on shadow evidence.

## 4. Monitoring

- HA debug logs: `local_nlu shadow aggregates: {...}` per shadowed
  request — fixed counter keys (`probes, matched, resolved, ambiguous,
  no_match, errors`) only; no IDs, mentions, spans, or utterances.
- Watch: `errors` counter, any `resolved` where v1 would abstain
  (divergence review), `stale`/`denied` drill outcomes.
- Latency reference (loopback, synthetic): `/v2/resolve` ~2.9 ms/case,
  `/v2/interpret` ~3.3 ms/case; residential timing will differ.

### Shadow scoping (what each loop proves — no equivalence claims)

Two separate loops, different guarantees:

- Residential identity-probe shadow (`shadow_enabled`): bounded probes
  (max 4 identity + 3 negative resolve calls) derived from the live
  snapshot against `/v2/resolve`. Proves the live snapshot resolves to
  itself and negatives abstain. Proves nothing about utterances, plans,
  actions, or ordering.
- Offline utterance comparison (frozen corpora + `shadow_utterances.py`):
  target-set comparison per ADR-0053 taxonomy. Equal sets are partial
  diagnostics only and never declare equivalent plans; actions, ordering,
  segmentation, and plan-equivalence are recorded not-evaluated.

Neither loop, alone or combined, evidences plan equivalence. Claiming
more than the taxonomy states is forbidden in pilot reports.

## 5. Reversão (rollback)

1. Set both options off → new requests are pure v1 immediately (no
   restart, no code change). Verify with R10.
2. If behavior is still unexpected, the v1 path is byte-identical to the
   frozen baseline (proven by `regression_gate.py`); code rollback is
   reverting the Step 7 commit. No migration, state, or data to unwind.

## 6. Residual risks and ACTIVE conditions

- Partial physical execution has no rollback (inherent to HA services);
  preflight-all plus per-call revalidation bound it; `operation_count`
  reports applied effects. Accepted by design, must be communicated.
- v2 abstains on ellipsis/queries/display-only singles by design; v1
  covers them via pre-routing. No silent behavior change while routing
  holds.
- TOCTOU between preflight and first effect is narrowed, not eliminated
  (same residual as v1).
- Query labels may differ textually between paths (`display_name` vs
  fused `names[0]`); identity is unaffected.
- Options flow renders raw field names until copy lands (cosmetic).
- ACTIVE requires: approvals (routing, shadow instance, abstention
  policy, no-clarification rendering, Step 7), green R1–R10 battery on
  the approved instance, rollback drill passing, and this runbook
  reviewed. Until then the feature is available but unused.

### Evidence package for pilot approval and ACTIVE marking

Archive, with dates and binary/source hashes, all of: offline gate
transcripts (Rust 80, Python 58, fmt, clippy, ER/MX/v2 freezes, gate
144/144 + 23/23); R1–R10 result log (outcome code + service-call count
per row, zero utterances persisted); differential report (§2.3) with
every divergence individually classified; rollback drill transcript
(flag-off byte-identity on the scripted set); a shadow counter window
export (aggregates only); stale/denied drill transcripts with zero
effects; review sign-off lines for each approval item. ACTIVE is marked
only when every evidence item exists and every approval is signed —
never automatically, never by default flip.
