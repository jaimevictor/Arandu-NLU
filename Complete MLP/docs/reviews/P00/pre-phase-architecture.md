# P00 Pre-phase Architecture Analysis

- Role: `phase-architect`
- Reviewer instance: `01a034d2-c041-7bf0-bb01-a57b7a8329cb`
- Input baseline: out-of-tree bootstrap steering attestation
  `15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539`
- Mode: read-only
- Result: `ANALYSIS_COMPLETE`

The analysis recommended a minimal P00 set containing repository rules, a
project license, clean-room and material records, ADRs, requirements
traceability, toolchain evidence, phase state/queue, review evidence, and trust
boundaries. It recommended Apache-2.0 project code, an initially std-only
`nlu-core`, a separate versioned JSON `protocol`, checked half-open UTF-8 byte
spans, typed extensible plans, fixed-point ranking, and independent PT-BR
quality/performance gates.

Alternatives considered and rejected included a single serialized core crate,
grapheme-only boundary offsets, closed Home Assistant domain enums, unordered
or floating-point semantic output, and treating Sophia's English benchmark as a
release oracle.

P01 must create only the core and protocol crates with their first consumers
and tests. Transport, linguistic datasets, catalog synchronization, and package
layout remain later phase-owned decisions unless needed to preserve a P01
boundary. ADRs 0003 and 0004 capture the P01 architecture; ADRs 0002 and 0007
bound later Home Assistant integration.
