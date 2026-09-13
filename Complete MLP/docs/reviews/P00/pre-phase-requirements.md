# P00 Pre-phase Requirements Analysis

- Role: `phase-requirements`
- Reviewer instance: `01a034d2-9eb7-7e51-a4e5-2216c41438f7`
- Input baseline: out-of-tree bootstrap steering attestation
  `15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539`
- Mode: read-only
- Result: `ANALYSIS_COMPLETE`

The analysis read all 843 steering lines and identified fourteen P00 acceptance
requirements: safe root, Git baseline, governance, clean-room boundary,
FOSS-only policy, Amazon exclusion, scope, measurable Home Assistant coverage,
linguistic provenance, benchmark contract, traceability, resolved P01
decisions, immutable review baselines, and independent P00 review.

It also identified eight P01 handoff requirements: a pinned Rust toolchain and
license rules; strict core/protocol boundaries; explicit span coordinates;
exclusive outcome states; canonical versioned serialization; stable extensible
typed plans; environment-independent determinism; and non-linguistic technical
fixtures.

Material contradictions found:

- the user's FOSS-only constraint overrides local use of non-redistributable
  data;
- the orchestration model must remain out of tree and cannot source language;
- the user removed the external supervisor script;
- "all domains" requires catalog-driven extensibility and fail-closed action
  schemas;
- Sophia's English claims cannot prove PT-BR equivalence;
- tracked review evidence needs a non-circular baseline convention.

These items are represented in the requirement matrix and ADRs 0001-0008.
