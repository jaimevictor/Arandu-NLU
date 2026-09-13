# P15 Aggregate-Only Held-Out Evaluation Result

- Date: `2026-09-10`
- Result: `P15_RELEASE_GATE_FAIL`
- Corpus class: `PROJECT_AUTHORED_SYNTHETIC`
- Claim class: internal conformance only
- Split: `heldout`
- Expected records: `4800`
- Observed records: `4800`
- Aggregate report bytes: `68142`
- Aggregate report SHA-256:
  `dbbed79f5dd34d9664f162b58614c9a5f537d568d8b92bc4eafab9f75cb11a75`
- Evaluator executable bytes: `15280736`
- Evaluator executable SHA-256:
  `4f44e720f729ec1883c49c8720a2483f114db50dd1b82c375f646e754d12a7e2`

## Chronology And Boundary

The run followed `docs/evidence/P15-EVALUATION-ACCESS.md`. The evaluator was
implemented without changing behavior-affecting product or linguistic bytes
from pre-implementation commit
`a055a847d22575fba8350d9e05fd8aff3797ece9`, tree
`24ac05687083a8fe8adb11e960a9e91bda158053`.

The sealed `release-evaluate evaluate` command produced canonical aggregate
JSON. No utterance, case identifier, semantic identifier, expected value,
mismatch, or per-case diagnostic was displayed or retained in repository
evidence.

Integration review then found that four initial evaluator tests independently
re-read the real held-out or performance splits while checking denominator,
projection, aggregate-output, and public-input behavior. Those tests emitted
no case material and changed no product byte, but their access violated the
fixture-only test boundary and the intended single sealed-reader chronology.
They were replaced with bounded `FIXTURE_TECNICA` records before this
checkpoint. The earlier access event nevertheless invalidates this evaluation
lineage for a passing P15 claim; the aggregate below is retained only as
failure evidence.

## Command

```text
release-evaluate evaluate --root /Users/jaimevss/Projects/NLU
```

The executable was built with the admitted Rust 1.98.0 host toolchain from
the reviewed `crates/release-eval` source using its locked offline graph.
This host run is evaluation evidence only; it is not native Linux artifact
or release-candidate evidence.

## Aggregate Result

Input reconciliation passed:

- expected records: `4800`;
- observed records: `4800`;
- all frozen dimension denominators present; and
- all five negative-suite denominators present.

Every scored plan case produced abstention or policy denial:

| Metric | Numerator | Denominator | Rate |
| --- | ---: | ---: | ---: |
| Intent exact | 0 | 4800 | 0% |
| Slot exact | 0 | 4800 | 0% |
| Entity exact | 0 | 4080 | 0% |
| Graph exact | 0 | 4800 | 0% |
| Final outcome exact | 0 | 4800 | 0% |

Observed outcome totals were:

- plans: `0`;
- clarifications: `0`;
- abstentions or denials: `4800`; and
- errors: `0`.

All independent negative suites retained zero false plans:

| Suite | Records | False plans | Gate |
| --- | ---: | ---: | --- |
| Safety-sensitive | 5 | 0 | PASS |
| Contradiction | 5 | 0 | PASS |
| Ambiguity | 5 | 0 | PASS |
| Stale-state | 5 | 0 | PASS |
| Explicit negative | 7 | 0 | PASS |

ASR noise remains `INSUFFICIENTLY_EVALUATED` because no eligible frozen ASR
stratum exists. The five clarification and twenty-two abstention cases remain
below the 237-case supported-stratum quota.

## Disposition

The global, per-stratum, and macro 98.4% conformance gates fail. The result is
not permission to inspect individual cases or tune product behavior against
this split. Product and linguistic bytes remain frozen, and P15 cannot freeze
a passing release candidate from this evaluation lineage.

## Non-Claimable Performance Diagnostic

The sealed runner also completed its performance-split diagnostic:

- report bytes: `364620`;
- report SHA-256:
  `8f42e3fa6d339a334f16aa3f007e8fd6b8fa5c833f94781b65ab902e1ef2a9bb`;
- semantic preflight reconciliation: `true`;
- semantic preflight SHA-256:
  `53bb64347f4d3ecbb4b5d1703f4d1368efc47670f39cc67bf7450e5af8b4683f`;
- three warmups and five measured runs completed for each Rust boundary;
- each measured sample exceeded one second by repeating complete corpus
  cycles; and
- startup diagnostic: `629960875` nanoseconds.

The result is ineligible for a performance claim. The semantic preflight
produced no exact plan, so eligible words and utterances were zero. Host,
single-thread, runner-source, and executable identities were intentionally
not asserted for this uncommitted macOS diagnostic. Peak RSS is unavailable
on this host. The real Rust-adapter, Python-companion, deterministic
Home-Assistant-fixture boundary remains `unmeasured_insufficient`; the
Rust-only protocol boundary is diagnostic and is not presented as end to end.
