# P02 Corpus-Free Fallback Evidence

- Phase: `P02`
- Pass: `3/3`
- Prototype: `exact_utf8_byte_match_v1`
- Workload class: `FIXTURE_TECNICA`
- Result: `MEASURED_BUT_INSUFFICIENT_FOR_P02_ACCEPTANCE`

## Contract

`tools/p02-fallback.rb` builds an immutable table from valid, nonempty UTF-8
strings and opaque nonnegative integer target IDs. It copies the original
bytes, sorts them as binary strings, rejects duplicate keys, and performs a
binary search for one byte-identical query. The table is limited to 65,536
entries; keys and queries are limited to 65,536 bytes.

The prototype does not normalize Unicode, infer morphology, label contextual
parts of speech, perform fuzzy matching, rank alternatives, consult
frequencies, or supply a semantic target. A miss returns no target. Malformed
UTF-8, an empty string, a non-UTF-8 Ruby string, an oversized input, a malformed
entry, and an out-of-range target fail closed.

All table and query strings used by the tests and benchmark are generated
technical fixtures prefixed `FIXTURE_TECNICA_`. They are not Portuguese,
linguistic, training, development, gold, or evaluation data and are excluded
from linguistic and semantic metrics.

## Reproduction

The empty-environment launchers use only the P00-admitted macOS Ruby standard
library:

```text
./tools/test-p02-fallback
./tools/benchmark-p02-fallback
```

The test runner passed eight tests covering unordered table construction,
exact hit and miss behavior, byte-distinct canonically equivalent Unicode
forms, duplicate keys, malformed table shapes and targets, empty/malformed/
oversized/wrong-encoding keys, invalid queries, and caller mutation after
construction.

The benchmark fixes 4,096 unique entries and 8,192 interleaved hit/miss
queries. Its full schema, table, query order, 128 cycles per run, three warmup
runs, and five measured runs are bound by SHA-256
`97a670c272a9ebc100d16b4eef33b5ec9a300524a5a543ff5eeefad28ad80ee6`.
Every run performed 1,048,576 lookups, observed 524,288 hits, and produced the
expected target sum `1073479680`.

Environment: macOS 26.6.2 build 25G83 on arm64; Apple Ruby 2.6.10p210,
reported platform `universal.arm64e-darwin25`. CPU brand and memory identity
remain unavailable in the sandbox, so this is not release-performance
evidence.

| Run | Seconds | Lookups/second | Nanoseconds/lookup |
| ---: | ---: | ---: | ---: |
| warmup 1 | 0.905683 | 1,157,773.75 | 863.73 |
| warmup 2 | 0.906388 | 1,156,873.22 | 864.40 |
| warmup 3 | 0.899846 | 1,165,283.84 | 858.16 |
| measured 1 | 0.901799 | 1,162,760.22 | 860.02 |
| measured 2 | 0.904680 | 1,159,057.35 | 862.77 |
| measured 3 | 0.910202 | 1,152,025.59 | 868.04 |
| measured 4 | 0.905013 | 1,158,630.87 | 863.09 |
| measured 5 | 0.905281 | 1,158,287.87 | 863.34 |

The measured median is `1,158,630.87` lookups/second. This metric is exact
table lookups per second, not words per second, utterances per second, semantic
accuracy, or a comparison with the P15 release thresholds.

## Source-Need Disposition

| Missing need | Corpus-free result |
| --- | --- |
| Lexicon | Can recognize only exact enrolled byte strings; supplies no entries |
| Morphology | No generalization or inflection analysis |
| Contextual POS evaluation | No labels, contexts, cases, or oracle |
| PT-BR Home Assistant semantics | Opaque targets require independently sourced mappings |
| Multi-intent evaluation | No graph labels, cases, or oracle |
| Frequency | Exact lookup uses no ranking, so frequency is unnecessary only for this narrow algorithm |

The fallback therefore measures a deterministic no-frequency implementation
route and satisfies the prototype obligation in `P02-SRC-007` and the fallback
branch of `P02-SRC-009`. It supplies zero external linguistic sources, zero
external oracle cases, and zero semantic coverage cases. It cannot freeze the
3,715 independently labeled scored cases, any 237-case stratum, the five
fail-closed suites, or the performance corpus required by ADR-0005.

## Conclusion

The exact-byte route is computationally viable but cannot replace an
independent linguistic and evaluation source portfolio. Treating opaque target
IDs or matcher output as gold would violate `GLB-EVAL-002`, `NFR-CASE-020`,
and `NFR-CASE-021`. Pass three is unsuccessful against P02 minimum acceptance,
and no candidate is eligible to freeze.
