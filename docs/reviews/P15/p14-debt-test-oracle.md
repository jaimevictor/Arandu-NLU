# P14 Debt Test-Oracle Review Carried By P15

- Role: `test-oracle`
- Analysis instance: `01a08ca2-fd76-7d22-a14e-4463cf055657`
- Review date: `2026-09-10`
- Subject commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Subject tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Authorized parent: `aeac316eafa065b8c36fece92afa9c6b333c2eea`
- Parent tree: `8427841cb17e0c1394216f038a2cb182bf412be1`
- Mode: independent, read-only
- Verdict: `FAIL`

## Baseline

The detached clone matched the exact subject and was clean. The reviewer
reproduced 141 passing companion tests, P14 validator self-tests, valid Ruby
syntax, 28 Rust binaries with 222 passing and three ignored tests, 38 Clippy
targets, the direct Rust build, and a clean whitespace check.

Mutation checks killed representative changes to child-exit polling,
multi-effect reconciliation, post-await epoch checks, reconciliation
capacity, stale state, governance identities, and P13 byte preservation.

## P1 — Operation-History Clock Exceptions Lack A Direct Oracle

Changing the broad exception handler at
`custom_components/local_nlu/ledger.py` line 159 from `Exception` to
`LedgerError` did not fail the named clock-coherence test because that test's
exception was absorbed during typed-session refresh. A direct operation
history sample made the exact subject fail closed with
`operation_history_failure`, while the mutant leaked raw `RuntimeError`.

The implementation is closed, but the required regression does not protect
that consumer.

## P1 — Fresh-Effect Marker Failure Lacks A Regression Oracle

Removing the failure raised when the restart-marker writer returns false at
`custom_components/local_nlu/ledger.py` lines 671-683 did not fail the
existing ledger or setup-lifecycle tests. A direct counterexample made the
exact subject stop with `restart_marker_persistence`, while the mutant
dispatched the effect.

## Classification

- P0: none
- P1: two
- P2: none
- P3: none

FAIL
