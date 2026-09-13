# P14 Debt Correctness Review Carried By P15

- Role: `correctness`
- Analysis instance: `01a08ca2-e54f-75c2-af05-203e2a2ab031`
- Review date: `2026-09-10`
- Subject commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Subject tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Authorized parent: `aeac316eafa065b8c36fece92afa9c6b333c2eea`
- Parent tree: `8427841cb17e0c1394216f038a2cb182bf412be1`
- Mode: independent, read-only
- Verdict: `FAIL`

## P1 — Failed Startup Loses Ownership Of A Credential-Bearing Helper

Primary evidence in `custom_components/local_nlu/helper_process.py` shows:

- capacity counts only `_records` at lines 243-254;
- the complete credential reaches the child before proof at lines 399-408;
- startup failure uses bounded termination at lines 430-448;
- the process record is removed before exit is proven at lines 458-468;
- the completed startup future is removed at lines 553-558;
- both terminate and kill waits may time out at lines 805-821; and
- shutdown can recover only processes still in `_records` or `_futures` at
  lines 291-349.

A child can therefore bind its pre-proof socket, receive the credential,
resist termination, disappear from capacity accounting, and become invisible
to later shutdown.

The existing non-exiting-child regression does not bind an endpoint or assert
retained ownership and capacity. The bound-endpoint test covers only proven
exit.

## Counterexample

Three helpers were provisioned against `MAX_LIVE_HELPERS = 2`. Each bound its
private socket, received the complete credential, timed out during proof, and
resisted terminate and kill waits.

```text
ADVERSARIAL_AFTER_1_RECORDS 0
ADVERSARIAL_AFTER_2_RECORDS 0
ADVERSARIAL_AFTER_3_RECORDS 0
ADVERSARIAL_MAX_LIVE_HELPERS 2
ADVERSARIAL_FAILED_HELPERS_ALIVE 3
ADVERSARIAL_LEAKED_ENDPOINTS 3
ADVERSARIAL_FAILURE_COUNT 3
ADVERSARIAL_FUTURES 0
ADVERSARIAL_ALL_RECEIVED_CREDENTIAL True
```

The temporary sockets were removed after the probe.

## Reproduced Checks

The exact subject and parent identities matched in a clean detached clone.
`git diff --check` passed. All 141 companion tests passed. Direct Rust
validation and Clippy passed; socket-denied test binaries were rerun outside
the restriction and passed.

## Classification

- P0: none
- P1: one, covering unresolved helper-exit and pre-proof-socket ownership
- P2: no separate finding
- P3: none

FAIL
