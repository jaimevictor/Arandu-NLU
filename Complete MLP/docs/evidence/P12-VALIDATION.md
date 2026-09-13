# P12 Bounded Session Continuation Validation

- Phase: `P12`
- Candidate: `77c2cb08d9871a808fe4fa32b4df96a7d47093f8`
- Candidate tree: `4b1e5461b2b6497bc78fe945504d1881e6dd8fba`
- Archive SHA-256: `e71fac40f32c2a34bd065b71f6155e21108e410bdc83508c0ae6058de2c0db6a`
- Convergence passes consumed: 1 of 3
- Substantive candidate rounds consumed: 3 of 3
- User-authorized evidence-only proof candidates: 1
- Validation date: `2026-08-29`
- Result: `PASS`

## Scope

P12 adds a standard-library-only `session-engine` and a separate resumable
plan-composition path. One opaque 32-byte session identifier addresses one
pending entity continuation. The record binds the originating invocation,
capability, exact node and slot, catalog generation, typed referents, original
evidence-bearing pending composition, and checked logical deadline.

The store permits at most 64 sessions, 16 referents per continuation, one
continuation per session, and a TTL no greater than 300,000 logical ticks.
All state transitions linearize under one mutex. Zero TTL, overflow,
rollback, collisions, substitutions, stale generations, ambiguity, replay,
and every one-over limit fail closed without eviction or truncation.

Session state has no serialization, persistence, network, filesystem, ambient
time, entropy, policy, authorization, execution, credential, or logging
surface. Protocol v1 is unchanged.

## Candidate Chronology

1. `cadf2d5` froze the first complete implementation. Reviews reproduced
   rollback ordering and test-oracle blockers.
2. `70ff592` corrected rollback handling. Reviews reproduced a missing result
   session binding and incomplete capacity-survival oracle.
3. `87d1d6c` bound results to sessions and proved all 64 retained entries.
   Reviews found that result-generation and current-generation substitutions
   were tested only in one coupled case.
4. `77c2cb0` is the one evidence-only proof candidate authorized by
   `USR-017`. It changes only `crates/session-engine/tests/contract.rs`,
   `tools/validate-p12.rb`, and `tools/test-validate-p12.rb`. Production,
   manifest, lockfile, schema, protocol, and data bytes are unchanged from
   candidate 3.

The first three entries consume the complete substantive round budget.
Candidate 4 is not another implementation or optional refinement pass.

## Verification

The candidate and closeout validation executed:

- `tools/validate-p12 --review-candidate`;
- `tools/test-validate-p12`, with all 10 mutation groups passing;
- focused locked session, plan, protocol, and core tests;
- full locked workspace tests;
- focused and workspace formatting, strict clippy, and all-target builds;
- inherited P10/P11 gates and protocol-v1 identity checks;
- exact archive, commit, tree, clean-state, and detached-clone reproduction;
- repeated deterministic schedules and real concurrent double-take tests;
- independent result-generation and current-generation substitutions;
- session, origin, capability, endpoint, referent, TTL, rollback, capacity,
  cancellation, and stale-generation counterexamples; and
- privacy, restart-empty, source-release, and filesystem canaries.

The exact detached-clone reproduction passed 277 workspace tests. Four
release libraries were byte-identical across two absolute roots. Unshipped
debug test executables retained absolute Mach-O paths and are explicitly
outside the release artifact identity claim.

## Independent Reviews

| Role | Instance | Verdict |
| --- | --- | --- |
| correctness | `p12-correctness-final-77c2cb08-20260829T141938Z` | `PASS` |
| risk | `01a04bf5-367e-7f82-b0c0-9cd382aa71c3` | `PASS` |
| test-oracle | `codex-p12-test-oracle-c4-77c2cb08` | `PASS` |
| reproducibility | `01a04bf5-3e35-7721-94be-b45095216a98` | `PASS` |
| runtime-adversarial | `01a04bf5-4d7a-7203-be86-cfdb347678a8` | `PASS` |
| requirements | `p12-requirements-77c2cb08-20260829T142100Z` | `PASS` |
| linguistics | `p12-linguistics-77c2cb08-20260829T142346Z` | `PASS` |

Every reviewer inspected primary evidence, attempted a counterexample, cited
reproducible commands and paths, confirmed the exact subject, and reported no
P0, P1, P2, or P3 finding.

## Requirement Completion

The evidence satisfies `GLB-SESSION-001..003`, `ARC-DIALOG-001`, and
`P12-SES-001..015`.

`P12-SES-016..020`, `P12-COMPAT-001..006`, and shared release requirements
remain pending for their assigned P13-P16 evidence. P12 does not claim caller,
pairing, transport, packaged restart, execution, or release-level privacy
completion.

## Completion

The reviewed candidate meets the written P12 minimum. The queue advances to
P13 without optional refinement.
