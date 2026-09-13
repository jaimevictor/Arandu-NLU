# P14 USR-047 Post-Review Correction Test-Oracle Review

- Role: `test-oracle`
- Review instance: `01a0916d-6fdc-77f2-9b46-0090ea2691f0`
- Subject commit: `f919aba0defb9c1d2bb773c7eef2b44071ccb17f`
- Subject tree: `d6bef59bc8ba9785ca6c245e014f1d8bf37d6388`
- Mode: independent read-only mutation and counterexample review
- Verdict: `FAIL`

The reviewer verified the exact clean subject and both byte-identical gate
transcripts, passed eight focused R5 regressions and validator self-tests,
and confirmed that the R5-04 and R5-05 omission mutants were killed.

A process-local mutation replaced `unittest.TextTestRunner.run` after test
discovery. It executed zero test bodies, printed all 199 discovered names,
and was accepted by the companion evidence parser:

```text
P14_COMPANION_EXECUTION_PASS count=199 identities_sha256=d11429c5ab86508a1a8208382220573c4ad0956623c5989e9c51aed519b24d7d
TEST_BODIES_EXECUTED=0
ACCEPTED_COUNT=199
```

The reviewer also reproduced governance and Noise markers accepted wholly or
partly on stderr because the generic runner concatenates both streams.
Governance counts `1`, `999`, and `1518` were all accepted.

- P0: none.
- P1: `P14-R6-04`.
- P2: `P14-R6-06`, `P14-R6-07`.
- P3: none.

`FAIL`
