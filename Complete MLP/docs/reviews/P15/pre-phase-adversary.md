# P15 Pre-Phase Safety And Adversarial Analysis

- Phase: `P15`
- Role: `independent-adversarial-analysis`
- Analysis instance: `01a08c7c-e942-78f0-b8df-60af2f1b202a`
- Input commit: `93ed8d75a4cb35f80572f8207105929b0071f48e`
- Input tree: `896a220ebb3e18905c2fc79d18779eecf547931c`
- Mode: read-only independent primary-evidence inspection
- Result: `THREAT_PLAN_SELECTED`
- P14 status: no phase PASS; exact-subject gate and mandatory reviews unrun

## Threat Hypotheses

| Severity | ID | Hypothesis and required control |
| --- | --- | --- |
| P0 | `P15-A01` | P15 launders inherited P14 validation debt into a release claim. Bind the exact P14 subject, unrun gate, six review roles, and previous blocker regressions; deletion or false closure of that debt must fail validation. |
| P0 | `P15-A02` | Accuracy appears acceptable because only clean plans are scored or abstentions, false plans, negative suites, ASR noise, and missing strata are omitted. Reconcile every denominator to frozen manifests, retain separate zero-false-plan gates, and report missing mandatory strata as `INSUFFICIENTLY_EVALUATED`. |
| P1 | `P15-A03` | Tracked held-out cases or case-level outputs influence tuning or targeted rules. Restrict final evaluation to a sealed aggregate-only evaluator, audit access chronology, prohibit product imports and per-case output, and invalidate affected results after established post-freeze semantic inspection. |
| P1 | `P15-A04` | Throughput is inflated by fixture code, easy-item repetition, fast abstention, omitted slow strata, hidden I/O, changed timing boundaries, or threading. Require semantic preflight, complete canonical corpus cycles, separate core and warm end-to-end boundaries, three warmups, five measured runs, raw samples, percentiles, spread, and resource data. |
| P1 | `P15-A05` | A reproducible artifact differs through timestamps, paths, ownership, locale, archive order, target labels, or post-build substitution. Bind every artifact to commit, tree, architecture, input inventory, tools, arguments, and `SOURCE_DATE_EPOCH`; compare two clean offline same-architecture builds in distinct roots. |
| P0 | `P15-A06` | SBOM, notice, or source-hash evidence omits the base image, runtime, helper, build tool, copied source, data, or transitive dependency. Require bidirectional release-byte and source-entry closure; deletion of any entry or injection of any executable, package, symlink, or layer must fail. |
| P0 | `P15-A07` | Cross-compiled or relabeled bytes masquerade as native `amd64` or `aarch64` evidence. Verify OCI platform, executable machine type, native Linux kernel and architecture, process execution, and clean installation on matching hardware; label-only changes and emulator-only proof fail. |
| P0 | `P15-A08` | Deterministic fakes substitute for the transferred real Home Assistant gate. Run admitted supported runtimes through the actual loader, config flow, authorization, dispatch, backup, and lifecycle paths; patched imports, fake entries, fake dispatch, and source-identity-only checks fail. |
| P0 | `P15-A09` | Install, restart, upgrade, rollback, removal, or interrupted transitions leave credentials, residential data, active epochs, helpers, sockets, or executable residue. Use unique canaries and before/after filesystem, backup, diagnostics, log, environment, process, and socket inventories; restart and rollback invalidate old epochs and require re-pairing. |
| P1 | `P15-A10` | Build or runtime performs undeclared network access. Deny build network; at runtime permit only the adapter's explicit Home Assistant channel and reject server/helper outbound access, telemetry, DNS, alternate endpoints, and undeclared clients. |
| P2 | `P15-A11` | Catalog breadth is reported as actionable coverage. Reconcile every pinned domain, typed operation, and capability while reporting catalog and actionable coverage separately. |

## Mandatory Schedules And Mutations

1. Verify immutable evaluation inputs, run semantic preflight, execute held-out
   once, expose only versioned aggregates, independently recompute metrics,
   and prohibit candidate changes derived from case-level results.
2. Mutate suite omission, outcome relabeling, duplicate credit, quota
   reduction, skipped errors, global-only passage, one-item repetition,
   incorrect output, sample deletion, hidden I/O, and omitted performance
   strata.
3. Freeze source, tool, and input identities; build twice offline for each
   architecture; compare same-architecture bytes; generate SBOM, notices, and
   checksums; then install the exact checksummed artifact.
4. Exercise clean install, restart and re-pair, upgrade, rollback, removal,
   and interruption before and after every persistent mutation, helper proof,
   and epoch activation on each admitted architecture and Home Assistant
   version.
5. Reject any enablement of artifact production or an architecture before
   native execution, real Home Assistant, reproducibility, source/license
   closure, lifecycle, and inherited P14 debt all pass.

## Counterexample

A runner scores only clean unambiguous plan rows, treats engine abstention as
unscored, omits negative suites, and reports no ASR stratum. It can report an
apparently perfect aggregate while producing unsafe plans for every negative
case. P15 must reject the run for denominator mismatch, missing mandatory
strata, incorrect abstention treatment, and absent independent false-plan
results.

## Bounded Convergence

One pass is one integrated evaluation, measurement, packaging, lifecycle, and
source-admission portfolio selected and then frozen, dispositioned, or
rejected. P15 allows at most three pre-candidate passes, followed by one
initial frozen candidate and at most two blocker-only replacements. Any P0
through P2 remaining after the applicable budget returns P15 to `BLOCKED`;
unused rounds are not optional refinement.

Minimum acceptance includes all P15-owned and inherited gates, both
transferred native and real-runtime gates, explicit P14-debt disposition,
disabled-to-enabled artifact evidence, and every mandatory reviewer passing
one immutable commit and tree.

## Primary Evidence

The analysis inspected `AGENTS.md`, both requirement ledgers, ADR-0001,
ADR-0002, ADR-0005, ADR-0007, ADR-0008, ADR-0037, ADR-0039 through ADR-0043,
`addon/`, `custom_components/local_nlu/`, P02 and P11 evaluation inputs, P10
coverage evidence, P14 validation and review reports, dependency and license
inventories, and phase state.

Representative commands included `git show` of the exact input commit and
tree, `git grep` for held-out access, chronology inspection of evaluation
inputs versus engine implementation, and full tree/path inventory. No write,
network, sibling, prohibited-source, or execution-oracle access occurred.
