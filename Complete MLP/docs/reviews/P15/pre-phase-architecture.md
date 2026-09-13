# P15 Pre-Phase Architecture Analysis

- Phase: `P15`
- Role: `independent-architecture-analysis`
- Analysis instance: `01a08c7c-e199-7441-8fb4-d8cfacf3bf05`
- Input commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Input tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Mode: read-only independent primary-evidence inspection
- Result: `CONVERGENCE_PASS_1_ARCHITECTURE_SELECTED_WITH_PRECONDITIONS`

## Baseline

The input baseline contains a P14 preflight result, not a minimally accepted
P14 checkpoint. The exact-subject gate, exhaustive governance mutation suite,
and six mandatory reviews are unrun. P15 design may proceed under ADR-0044,
but no architecture, artifact, P14 PASS, or release claim follows from that
preflight.

## Evaluation And Measurement

Add one non-shipped P15 evaluator that calls the actual production path through
`nlu_server::NluRuntime::dispatch_at`. It must not duplicate intent, graph,
policy, or session logic.

The evaluator:

- reads only frozen hash-verified P02 held-out and negative-suite inputs;
- uses a fixed catalog and logical clock;
- emits aggregate-only canonically ordered metrics for intent, slot, entity,
  graph, final outcome, clarification, abstention, and false plans;
- keeps each negative suite outside the accuracy denominator as an independent
  zero-false-plan gate;
- binds corpus, executable, runner, source commit, tree, and metric-schema
  identities; and
- emits no held-out text, case identifier, or per-case diagnostic.

Any required stratum without eligible pre-engine frozen cases is reported as
insufficiently evaluated. P15 may not generate post-hoc linguistic cases or
convert the project-authored conformance corpus into an independent-accuracy
claim.

Performance uses the same production code path and the ADR-0010 word-count
contract. An untimed exact-semantic complete-corpus and per-stratum preflight
precedes three warmups and five complete canonical measured runs. The core
boundary is single-threaded and excludes startup, I/O, and adapters. The warm
end-to-end boundary includes protocol, adapter, companion, and deterministic
non-residential Home Assistant fixture behavior. Reports retain raw samples,
p50, p95, p99, spread, throughput, RSS, startup, artifact sizes, and exact
hardware, kernel, compiler, profile, corpus, and data identities.

## Release Topology

The minimum release unit is:

- one common companion archive containing Python source and native helpers at
  `custom_components/local_nlu/bin/{amd64,aarch64}/companion-helper`;
- one Linux OCI add-on artifact for each admitted architecture; and
- one canonical release manifest binding every artifact, metadata file, mode,
  architecture, and SHA-256 digest.

The preferred minimum root filesystem is empty OCI `scratch` semantics with
statically linked native binaries plus project-owned configuration, data, and
legal files. Source discovery must first admit the compiler, linker, static
runtime closure, OCI executor, and real Supervisor compatibility. If that
portfolio fails, only a pinned FOSS fallback with complete source-to-binary
and license closure may replace it.

Each architecture is built natively and offline from admitted inputs, with
source mounted kernel-enforced read-only and outputs written to clean
architecture-specific roots. Two builds from different absolute paths must be
byte-identical for the same architecture. Ordering, paths, ownership, modes,
and timestamps are normalized from `SOURCE_DATE_EPOCH`; cross-architecture
byte equality is neither required nor accepted as a substitute for
same-architecture reproducibility.

## Supply-Chain Evidence

Each artifact requires:

- deterministic SPDX 2.3 JSON SBOM;
- generated complete third-party notices and applicable license bytes;
- SHA-256 checksum manifest;
- a complete release-input inventory covering source archives, vendored
  dependencies, compilers, linkers, OCI executor, root filesystem, runtime
  closure, transformations, and hashes; and
- reconciliation proving every shipped byte is project-owned or represented
  by admitted source and rights evidence.

No unadmitted SBOM, archive, packaging, container, or signing executable may
enter the release procedure.

## Native And Real Home Assistant Gates

For both architectures, run the native Linux build, runtime, process
isolation, and rejected-source reachability gates transferred by ADR-0039.
Run clean real-runtime lifecycle tests against pinned Home Assistant 2026.8.3
and the exact later release identity frozen before P15 candidate review.

The matrix covers clean dual-deliverable installation; helper mode and
architecture selection; pairing, recognition, and one caller-authorized
operation; restart and re-pairing; supported upgrade with both component-order
skews failing closed while versions differ; rollback; backup and restore
without transferable secrets or active epochs; complete removal; outbound
network denial; peer credentials; memory locking; dump prevention; and procfs
exposure.

## P14 Debt Lane And Enablement

P15 independently retains these blocking steps for immutable subject
`93ed8d75a4cb35f80572f8207105929b0071f48e`:

1. Run the complete clean exact-subject P14 gate.
2. Complete the exhaustive governance mutation suite.
3. Obtain all six mandatory independent reviews against the same commit and
   tree.
4. Record acceptance or a newer explicit user-authorized disposition.

P15 work does not convert P14 preflight into a PASS. Any P15 change overlapping
P14 behavior must also revalidate the inherited requirements on the P15
candidate.

Architecture state advances only through:

`disabled -> build-admitted -> native-validated -> HA-lifecycle-validated -> reproducible -> enabled`

`artifact_build_allowed` remains false and neither architecture is shippable
until both architectures and every applicable release and debt gate pass.

## Required Decisions

Before implementation freeze, accepted ADRs must bind:

1. native executors, compiler, linker, static runtime, OCI executor, and real
   Home Assistant runtime closure;
2. final empty root filesystem or admitted fallback base image;
3. artifact topology, archive and OCI formats, reproducibility rules, SBOM,
   notices, checksums, and release-input inventory;
4. supported upgrade, rollback, version-skew, backup, and removal matrix; and
5. aggregate held-out isolation and benchmark boundaries where existing ADRs
   do not bind the concrete implementation.

## Counterexample

A companion archive can be byte-reproducible while consistently stripping the
executable bit from `bin/aarch64/companion-helper`. Host mocks and OCI builds
can pass, but a real aarch64 installation cannot start or pair the helper.
Reproducibility alone therefore cannot admit an architecture; packaged-mode
inspection and actual clean install, startup, upgrade, and rollback are
mandatory.

## Bounded Convergence

One pass is one integrated selection, freeze, disposition, or rejection of the
evaluator and benchmark boundaries, executor and root-filesystem portfolio,
two-architecture artifact topology, supply-chain evidence, lifecycle matrix,
and P14-debt treatment. At most three pre-candidate passes are available.

Minimum acceptance requires every P15-owned and inherited mandatory row,
accuracy and negative-suite gates without unsupported claims, performance
gates, complete source and tool admission, two identical clean builds per
architecture, complete supply-chain reconciliation, native and real-runtime
gates, P14-debt closure or explicit disposition, and every mandatory reviewer
passing one immutable subject. Failure by pass three blocks P15 and does not
permit partial architecture enablement.

## Primary Evidence

The analysis inspected `AGENTS.md`, ADR-0001 through ADR-0010, ADR-0037
through ADR-0043, add-on and companion contracts, helper lifecycle source,
workspace manifests, evaluation and benchmark crates, P02 corpus manifests,
distribution and toolchain evidence, P14 validation and reviews, P15
traceability rows, and phase state.

Representative commands used exact-commit `git show`, `git ls-tree`,
`git grep`, and parent diff inspection. No write, network, sibling,
prohibited-source, or execution-oracle access occurred.
