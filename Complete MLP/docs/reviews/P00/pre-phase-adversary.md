# P00 Pre-phase Adversarial Analysis

- Role: `phase-adversary`
- Reviewer instance: `01a034d2-efa4-7ec0-8157-3352029f380a`
- Input baseline: out-of-tree bootstrap steering attestation
  `15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539`
- Mode: read-only
- Initial result: `P00 FAIL` because no P00 candidate existed

The adversary produced the following blocking hypotheses for the implementation
to address before review:

| Severity | Hypothesis | Required mitigation |
| --- | --- | --- |
| P0 | Steering could admit non-redistributable data despite FOSS-only user rule. | Override with open modification/redistribution policy and explicit NC/ND/research-only rejection. |
| P0 | A repository wrapper license may not cover its corpus. | Record path-level scope, rights holders, underlying rights, transformation lineage, and output license. |
| P0 | "Public Sophia research" could launder proprietary behavior or translated benchmark data. | Restrict exposure to claims/methodology audit and prohibit adapters, runtime probing, translation, data, and oracles. |
| P0 | `FIXTURE_TECNICA` could hide AI-generated language. | Permit only non-language structural markers and require removal independence. |
| P1 | Sophia comparison was non-falsifiable. | Separate PT-BR exact-semantic, false-plan, core throughput, end-to-end, and resource measurements. |
| P1 | "All HA domains" had no denominator or safety semantics. | Pin a HA baseline, emit a capability matrix, and reject arbitrary service calls. |
| P1 | Add-on packaging did not establish an Assist integration route. | Select and verify official Wyoming/add-on/API contracts and require real HA integration tests. |
| P1 | Determinism mixed semantic, stateful, package, and measurement behavior. | Define separate semantic, adapter, build, and measurement envelopes. |
| P1 | Proprietary or Amazon-specific tooling could become a hidden dependency. | Keep orchestration out of tree; require public FOSS build/test/runtime paths without private credentials. |
| P1 | User decisions were not persistent. | Assign requirement IDs, owners, tests, and evidence. |

The implementation responses are ADRs 0001, 0002, 0005, 0007, and 0008;
`BOUNDARY.md`; `SOURCE-POLICY.md`; `USER-DECISIONS.md`; and the requirements
matrix. These are mitigation claims only; post-phase reviewers must try to
refute them against the frozen candidate.
