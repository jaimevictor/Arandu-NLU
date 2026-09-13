# P15 Qualification And Release Report

- Phase: `P15`
- State: `BLOCKED`
- Subject baseline: `P15_PRE_IMPLEMENTATION_SELF`
- Candidate: `NOT_FROZEN`
- Result: `BLOCKED_BEFORE_CANDIDATE_REVIEW`

## Delivered

P15 adds three non-shipped release-support components:

- `crates/release-eval`, a hash-bound aggregate-only evaluator over the
  production protocol-v2 `NluRuntime::dispatch_at` path with exact semantic,
  Wilson, frozen-stratum, independent false-plan, and bounded benchmark
  reporting;
- `crates/release-packager`, a dependency-free deterministic POSIX ustar,
  scratch OCI, SPDX 2.3, manifest, checksum, authorization, and bidirectional
  shipped-byte reconciliation library; and
- `tools/validate-p15`, a fail-closed release-candidate validator with
  mutation self-tests for frozen inputs, access chronology, native
  architecture identity, real Home Assistant lifecycle evidence,
  reproducibility, release bytes, reviews, and post-review immutability.

Artifact production remains disabled. No amd64 or arm64 release image,
companion package, SBOM, notice bundle, or release candidate is claimed.

## Evaluation

The sealed runner reconciled all 4,800 held-out plan cases and all 27
independent negative cases. It emitted canonical aggregate JSON only.

The held-out plan result failed:

- intent exact: `0 / 4800`;
- slot exact: `0 / 4800`;
- entity exact: `0 / 4080`;
- graph exact: `0 / 4800`;
- final outcome exact: `0 / 4800`; and
- observed plan outcomes: `0`.

Every scored plan request abstained or was denied. All five negative suites
retained zero false plans. ASR noise remains insufficiently evaluated.

The performance diagnostic completed three warmups and five measured runs for
the core and Rust protocol-runtime boundaries, but no sample was gate-eligible
because the semantic preflight produced zero exact plans. The real
Rust-adapter, Python-companion, deterministic Home Assistant fixture boundary
remains unmeasured and is not relabeled as end to end.

During integration review, the executor found that initial evaluator tests
also read the real frozen splits directly. No case material was emitted and
no product byte was changed, but tests are required to use only
`FIXTURE_TECNICA` records. Those tests were replaced with bounded mechanical
fixtures before checkpointing. The earlier access event remains part of the
failed P15 lineage and cannot create a passing claim.

## Inherited P14 Review Debt

Six independent roles reviewed exact P14 subject
`93ed8d75a4cb35f80572f8207105929b0071f48e`, tree
`896a220ebb3e18905c2fc79d18779eecf547931c`.

| Role | Verdict | Highest finding |
| --- | --- | --- |
| Requirements | PASS | none in narrow requirements scope |
| Correctness | FAIL | P1 untracked credential-bearing helper |
| Test oracle | FAIL | P1 missing direct safety regressions |
| Risk | FAIL | P0 restart marker not durable before dispatch |
| Reproducibility | FAIL | P1 incomplete exact acceptance; P2 raw log nondeterminism |
| Runtime adversarial | FAIL | P0 restart marker; P1 helper ownership |

The executor independently reproduced the P0: Home Assistant mutates
config-entry memory immediately but delays durable storage, so a crash can
lose the restart barrier and a new runtime can dispatch the same effect
again.

## Native And Real-Runtime Preconditions

The current host has no admitted native Linux amd64 executor, native Linux
arm64 executor, admitted Linux target and linker closure, OCI executor, real
supported Home Assistant Supervisor lifecycle environment, or reference
hardware for the warm end-to-end gate.

Cross-compilation, emulation, architecture relabeling, proprietary container
stacks, and mock-only lifecycle evidence remain ineligible.

## Convergence Disposition

Pass one selected the integrated scratch, musl, native-Linux, real-Home-
Assistant, sealed-evaluation, and project-authored packaging portfolio. The
implementation is now rejected as a release candidate by:

- the reproduced inherited P14 P0 safety defect;
- the P14 P1 helper-process ownership defect;
- the 0% held-out exact-semantic result;
- the evaluator-test access-boundary violation;
- unavailable native Linux and real Home Assistant resources; and
- absent warm end-to-end evidence.

No safe in-scope pass two exists. Correcting companion or NLU behavior would
change bytes frozen by `P15-EVALUATION-ACCESS.md` and invalidate the current
held-out lineage. The GNU-root fallback is not eligible because scratch has
not failed an admitted native Supervisor compatibility test. A release
candidate was therefore not frozen.

## Required Scope Decision

Continuation requires explicit authority and resources to:

1. reopen the exhausted P14 behavior scope for a consolidated safety
   correction;
2. establish a new deterministic, pre-correction, untouched evaluation
   lineage before any behavior change;
3. diagnose and correct the zero-plan behavior using only eligible non-held-
   out evidence;
4. provide admitted native Linux amd64 and arm64 execution plus a supported
   real Home Assistant lifecycle environment; and
5. rerun P15 before P16 or FINAL.

P16 and FINAL remain queued. No phase PASS, release readiness, artifact
enablement, or `DEVELOPMENT_COMPLETE` claim is made.
