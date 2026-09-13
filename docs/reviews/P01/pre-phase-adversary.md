# P01 Pre-phase Adversarial Analysis

- Role: `phase-adversary`
- Reviewer instance: `01a044c8-1791-7c83-b3c1-4ab802577b17`
- Input baseline: `ec2f05c4ecc0411b1ff010b31a5199de127cc413`
- Mode: read-only
- Result: `ANALYSIS_COMPLETE`

The implementation must close these hypotheses before candidate freeze:

| Severity | Hypothesis | Required mitigation |
| --- | --- | --- |
| P0 | Plans can carry credentials, raw service names, arbitrary JSON, callbacks, or authority. | Make these states structurally unrepresentable and audit the public API. |
| P0 | A malformed, unsupported, ambiguous, or over-limit request can become a plan. | Fail closed through bounded protocol errors only. |
| P1 | Post-parse checks permit hostile allocation before rejection. | Enforce wire bytes, decoded string bytes, depth, and collection limits while parsing. |
| P1 | A valid span for one request can be reused against another. | Bind every span to immutable source identity and validate evidence against that source. |
| P1 | Unicode or separators create identifier aliases. | Use a bounded ASCII namespace/local grammar and reject controls, confusables, empty parts, and extra separators. |
| P1 | A graph accepts duplicate IDs or slots, dangling or duplicate edges, self-edges, ordering cycles, or stale entities. | Validate all graph invariants in constructors and DTO conversion. |
| P1 | A protocol error is modeled as a semantic interpretation result. | Keep three core outcomes inside a distinct four-way protocol envelope. |
| P1 | Error text leaks hostile input, paths, keys, or parser diagnostics. | Expose closed codes and bounded numeric metadata only. |
| P1 | Standard-library-only code still reads environment, time, filesystem, entropy, or network. | Source-audit forbidden ambient APIs and replay under environmental permutations. |
| P2 | JSON Schema is treated as proof of duplicate-key, byte-limit, or canonical-order behavior. | Keep these as executable parser and serializer gates. |

## Required Adversarial Tests

Exercise every UTF-8 boundary over technical multibyte markers; reversed,
overflowing, stale-source, and empty evidence spans; malformed namespaced
identifiers; graph count boundaries and cycles; all illegal slot, relation,
outcome, and DTO combinations; duplicate literal and escaped JSON keys; BOM,
comments, invalid UTF-8, fractions, exponents, overflow, trailing and
concatenated values; N-1/N/N+1 byte, depth, string, and collection limits; and
canonical byte equality under input order, whitespace, escape, locale,
timezone, current-directory, and environment permutations.

Leak tests place a unique canary in keys and values and require its absence
from serialized errors, `Display`, `Debug`, and panic output. Source audits
reject unordered semantic maps, floats, arbitrary JSON values, public raw
fields, callbacks, ambient I/O/time/state APIs, transport/authentication
dependencies, raw service payloads, and unlabeled linguistic fixtures.

## Counterexamples

Private offsets alone do not bind spans to text. A vector alone does not
canonicalize semantically unordered input. Dependency-free core code can still
perform ambient I/O. Injected clock and ID traits do not prevent a second
ambient code path. One distribution archive hash does not by itself attest
every invoked compiler component or linker.

Evidence inspected: `AGENTS.md`, ADRs 0001, 0003, 0004, and 0008,
`docs/evidence/REQUIREMENTS-TRACEABILITY.md`,
`docs/evidence/TOOLCHAIN-PROVENANCE.yaml`, and the P00 closeout. Commands used
included `find`, `grep`, `sed`, `awk`, `nl`, `wc`, and `git status`.
