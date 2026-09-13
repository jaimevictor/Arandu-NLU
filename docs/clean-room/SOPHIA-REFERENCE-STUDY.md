# Sophia Public Reference Study

- Study date: 2026-08-24
- Purpose: define independent acceptance targets
- Classification: `EXTERNAL_UNVERIFIED_NON_GATING`

## Clean-room scope

The study used public marketing pages and the public Aquila aggregate benchmark
repository at commit
`c8c0de27a08a233aed5286562f5f4506d33bb857`. No Sophia engine, binary, model,
vocabulary, private format, live output, or `cicero-sophia` implementation was
inspected or used. No benchmark code or utterance is copied into this project.

The benchmark repository was audited as an external claim, not admitted as a
dependency or dataset. Its nominal MIT file contains unfilled copyright fields,
so it fails this project's source-admission policy.

## Public claims

| Claim | Public value | Project treatment |
| --- | --- | --- |
| Home Assistant suite | `3655/3715`, 98.4%, 10.1 s | External English result; numerical accuracy target only |
| Older Home Assistant pages | 99.0% | Stale/inconsistent; non-gating |
| Core parser | approximately 20,000 words/s, one thread | Separate workload; independent core target |
| Binary | 24 MB | Non-gating context |
| Runtime memory | 160 MB | Non-gating context |
| Vocabulary | 106,322 English words | Not transferable to PT-BR; never a source |

The public Home Assistant result is English. Public materials also advertise
offline operation, deterministic behavior, multi-intent handling,
clarification, short-term state, and Linux `amd64`, `aarch64`, and `armv7`
availability. These are product claims, not verified implementation facts.

## Benchmark audit

The suite reports 3,715 scored cases but contains 4,035 actual utterances because
two-turn cases count once. The audited text has approximately 32,321
whitespace-delimited words.

Derived from the reported 10.1-second run:

- 367.8 scored cases/s;
- 399.5 utterances/s;
- 3,200 words/s;
- 2.72 ms per scored case.

This demonstrates that the approximately 20,000 words/s parser claim is not the
same measurement as the Home Assistant run.

| Category | Result |
| --- | --- |
| Area control | 825/842 |
| Device control | 953/958 |
| Area queries | 859/862 |
| Device queries | 446/450 |
| Multiple intents | 121/124 |
| State persistence | 295/320 |
| Timers | 125/126 |
| Lists | 31/33 |

## Validity limits

- English only and strongly templated.
- Authored and published by the Sophia developer, creating tuning and
  independence risk.
- No utterance provenance, human-validation record, anti-leakage split policy,
  or held-out guarantee.
- Hardware and operating environment are undocumented.
- Setup and configuration loading are excluded from timing.
- Some timer/list/scene/script checks accept partial or fallback behavior.
- The benchmark's entity tagging and integration setup may favor a specific
  adapter.
- It cannot be translated or reused as PT-BR gold data.

## Project conclusion

ADR-0005 retains 98.4% exact semantic success as an internal conformance target
on a frozen project-authored PT-BR Home Assistant corpus, 20,000 words/s on a
separately defined single-thread core benchmark, and 400 utterances/s on the
warm end-to-end NLU path. False plans are gated separately. The project-authored
corpus is not an independent accuracy gate, and no claim of direct Sophia
equivalence is permitted unless language, workload, oracle, hardware, and
timing boundaries become genuinely comparable.

## Public references

The mutable claim pages were fetched on 2026-08-24. Their response bytes are
not redistributed; exact byte counts and SHA-256 values make the observation
identity reproducible:

| URL | Bytes | SHA-256 |
| --- | ---: | --- |
| <https://nlu.to/> | 15,231 | `a624151273212f4822d755c5f3e386b514df5f7fdc460755fd170c2d9589f8d9` |
| <https://nlu.to/ha/> | 20,072 | `398525ac83ad7d88812be27864a672042a7e5c43cc3a872676148fff548517c8` |
| <https://nlu.to/ha/tests> | 14,756 | `46189f84c0fc0878e631a2c4839e9330c97e6d9febec9deecdc019490abecbb5` |
| <https://nlu.to/ha/faq> | 20,330 | `72dbf59d0e51825414d00caea7d00ae61c9077861368b49285158de2ba5e3b7a` |
| <https://nlu.to/r/ha_v20000> | 21,892 | `fecf9988b6c519327a7729daaef20526bc804e3fc755641d190e0096bfde371f` |
| <https://cicero.sh/sophia/specs> | 17,784 | `1e06404fd211801916320cfedd2b72f5d1f3ba1a3d0c13e5a109cce3635ec461` |

The aggregate benchmark repository is
<https://git.cicero.sh/aquila/ha-voice-test-suite> at the commit identified
above.
