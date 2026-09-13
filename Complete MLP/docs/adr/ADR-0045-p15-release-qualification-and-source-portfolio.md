# ADR-0045: P15 release qualification and source portfolio

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-09-10
- Owners: P15-P16, FINAL

## Context

P15 must qualify the actual production NLU path, build one companion package
and two native Linux add-on artifacts, prove real Home Assistant lifecycle
behavior, and reconcile every shipped byte to admitted source and license
evidence. ADR-0039 and ADR-0040 transferred native Linux and real Home
Assistant execution to P15. ADR-0044 also carries the incomplete P14
exact-subject gate and review set.

The executor is macOS arm64. It has no admitted Linux virtual machine,
container executor, native amd64 host, native Linux Rust target, musl or glibc
runtime closure, Home Assistant Supervisor runtime, or OCI executor. The
admitted Rust installation contains only `aarch64-apple-darwin`.

The P02 freeze contains 4,800 held-out clean-text plan cases, 4,800
performance clean-text plan cases, and 27 non-plan cases across five
independent fail-closed suites. It contains no ASR-noise accuracy stratum.
Existing P09 and P11 evaluators intentionally bind only train and development
inputs and cannot be relabeled as final evaluation.

On 2026-09-10 the official Home Assistant latest-release endpoint resolved to
tag `2026.9.1`, commit
`fc034572d0216a04ed40a07154394908a594dfed`, and tree
`4b2a1cd29e3d85c43d791e03eb82a17244956fec`. Its source declares Python
`>=3.14.2`. This identity is a quarantined P15 admission candidate, not an
admitted runtime.

## Decision

P15 convergence pass one selects the following integrated qualification
architecture with unmet external preconditions.

### Evaluation

Add a shared, non-shipped mechanical evaluation contract that derives typed
cases only from the frozen P02 specification, projections, manifests, and
hash-bound corpus bytes. A sealed P15 runner is the sole filesystem reader for
held-out inputs.

The runner must:

- call `nlu_server::NluRuntime::dispatch_at` through protocol v2;
- expose only canonical aggregates, stable error codes, whole-run identities,
  and whole-run digests;
- never expose utterances, case IDs, semantic IDs, expected values, or
  per-case diagnostics;
- report exact intent, slot, entity, graph, final-outcome, clarification,
  abstention, and false-plan metrics;
- report every frozen dimension, unweighted macros, Wilson intervals, and
  support disposition;
- treat ASR noise as `INSUFFICIENTLY_EVALUATED` with denominator zero and no
  support claim;
- keep all five negative suites and every suite class as independent
  zero-false-plan gates; and
- count a comparable exact plan carried by `CompletePlan`,
  `ConfirmationRequired`, or `PolicyAccepted` as semantic plan output while
  never treating policy denial or abstention as a plan.

Suite utterances and expected outcomes remain immutable. Deterministic
catalog, stale-state, session, and alias event scripts may be added only as
`FIXTURE_TECNICA` mechanical context.

Performance uses the same projected corpus and semantic comparator. An
untimed complete-corpus and per-stratum semantic preflight precedes exactly
three warmups and five measured complete-corpus runs. Core timing uses a
shared production interpretation seam. Warm end-to-end timing must traverse
the real Rust adapter boundary and real Python companion parser and engine
with an in-process deterministic non-residential Home Assistant fixture.

### Release topology

The release unit is exactly:

1. one mode-preserving deterministic POSIX ustar companion archive containing
   the Python integration, project license and notices, plus executable
   `bin/amd64/companion-helper` and `bin/aarch64/companion-helper`;
2. one scratch OCI image for `linux/amd64`; and
3. one scratch OCI image for `linux/arm64`.

Each OCI root contains only the add-on adapter, NLU server, runtime contract,
required empty runtime directories, and legal metadata. `/data`, `/dev`, and
`/proc` remain runtime mounts.

Project-authored deterministic code emits the ustar archive, OCI layout,
SPDX 2.3 JSON SBOM, notices, checksums, release manifest, and bidirectional
release-byte/source-input reconciliation.

### Source portfolio

The selected portfolio is native Linux Rust 1.98 plus both musl targets,
`rust-lld`, exact musl CRT/libc closure, native amd64 and aarch64 hosts,
an admitted OCI executor, and admitted Home Assistant Core, Supervisor,
Python, and dependency closures.

A minimal dynamic GNU root filesystem is the sole bounded fallback, and only
after a concrete native Supervisor compatibility failure rejects scratch.
Official base images combined with Docker, Podman, Buildah, Skopeo, Syft, or
similar stacks are rejected for this phase because they add a substantially
larger unadmitted source and runtime closure.

Cross-compilation, emulation, architecture relabeling, Docker Desktop,
Homebrew Python, the rejected Home Assistant virtual environment, mock-only
lifecycle tests, and Cargo-by-presence cannot satisfy native or real-runtime
gates.

### Enablement

Architecture state remains:

`disabled -> build-admitted -> native-validated -> HA-lifecycle-validated -> reproducible -> enabled`

`artifact_build_allowed` remains false and both architectures remain disabled
until every state transition, P15 release gate, and inherited P14 debt gate
passes. A failed or unavailable external precondition is recorded as a
blocker; it is never converted into host-only evidence.

## Consequences

- Convergence pass one is consumed by this integrated selection.
- Evaluation and deterministic packaging code may proceed without enabling
  artifacts.
- The latest Home Assistant source identity is frozen, while runtime use
  remains prohibited until full admission.
- P15 cannot reach a candidate review baseline on the current host without
  actual native Linux amd64 and aarch64 resources plus an admitted real Home
  Assistant lifecycle environment.
- Text-only support may be evaluated; no ASR robustness claim is permitted.

## Rollback

If scratch fails an actual admitted native Supervisor compatibility test,
record that failure and select the GNU fallback as convergence pass two. If
the external native or real-runtime preconditions remain unavailable after
the bounded portfolio process, keep artifacts disabled and stop P15 as
blocked without weakening the gate.
