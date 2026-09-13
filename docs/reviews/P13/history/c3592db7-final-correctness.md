# P13 Final Correctness Review

- Role: `correctness`
- Review instance: `9A68F43F-A771-41F0-9750-A4696D9CC03C`
- Subject commit: `c3592db753814c36640a4e8a9b43492e6843bcfc`
- Subject tree: `7ab5b72f4113e883196bec00425e7de261492d60`
- Archive SHA-256: `9ae30b0458521028ad96533215d5db3dc1a1de719d944c75cf718c0b4677b0d3`
- Mode: independent read-only
- Verdict: `FAIL`

## Scope And Commands

The reviewer inspected policy, protocol v1/v2, server, compatibility, and
Noise evidence code and tests. `tools/validate-p13 --review-candidate`, all
13 `tools/test-validate-p13` groups, the Noise mutation suite, focused
equal-length source-substitution tests, exact Git/archive identity, and
`git diff --check` passed.

## Counterexample

Equal-length source substitution was correctly rejected by policy and
protocol. A separate lock-consistency probe showed that the tracked lock has
45 entries and hash `78010b6c...8df379`, while the material record identifies
the parent lock. Direct `validate_materials` still returned true.

## Findings

P0: none. P1: none. P2: `P13-COR-001`, contradictory source lock identities
pass the mandatory gate because there is no cross-ledger predicate. P3: none.

`FAIL`
