# P15 Evaluation Feasibility Review

- Role: `evaluation-feasibility`
- Analysis instance: `01a08c8d-2098-7e33-9b94-6dea89a8f0eb`
- Subject commit: `7ad4bcb6e568438269a61a9704e669de1bbd3e62`
- Subject tree: `00a1dfe98bed337f9f8b39273fb1e7456365a95e`
- Mode: read-only
- Result: `FEASIBLE_WITH_REQUIRED_NEW_CONTRACT`

## Finding

The 4,800-case held-out and performance clean-text sets are fully gateable,
including every recorded mandatory stratum. The 27 cases in the five
fail-closed suites can support independent zero-false-plan gates after
mechanical event contexts are specified.

No ASR-noise accuracy cases exist. ASR must be reported as
`INSUFFICIENTLY_EVALUATED`. The five expected clarifications and 22 expected
abstentions are separate non-plan safety metrics, not 237-case supported
accuracy strata.

Existing intent and plan evaluators bind only train and development and cannot
be extended by relabeling. P15 requires a shared mechanical frozen-data
contract and a sealed aggregate-only runner over the actual protocol-v2
`NluRuntime::dispatch_at` production path.

## Required Controls

- Only aggregate types are public.
- Errors reveal no utterance, case ID, semantic ID, expected value, or
  per-case diagnostic.
- Exact plans embedded in `CompletePlan`, `ConfirmationRequired`, or
  `PolicyAccepted` are comparable semantic output.
- Policy denial, clarification, or abstention on a scored plan is failure.
- Every suite class is an independent false-plan gate.
- Mechanical stale-state, alias, and session scripts are
  `FIXTURE_TECNICA` and cannot change frozen language or labels.
- Core and warm end-to-end benchmark boundaries remain separate; the latter
  traverses the real Python companion with an in-process deterministic Home
  Assistant fixture.

## Counterexamples

The implementation must reject a globally passing report with one failing
stratum, a missing ASR row, a 236-case stratum, an omitted suite class, a fast
abstention counted toward throughput, a report containing a case ID, or a
Rust-only end-to-end mock that skips the Python companion.

## Evidence

The review inspected ADR-0005, ADR-0008, ADR-0010, the complete P02 manifest
and generator specification, all five suite files, evaluation schemas,
existing evaluator projection code, `NluRuntime`, protocol v2 outcomes,
adapter seams, and companion execution seams. It reconciled all twelve P02
artifact hashes, byte counts, and record counts without inspecting held-out
case content or executing the engine.
