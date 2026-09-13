# Historical P00-P16 Requirements Traceability

> Retained for audit history only. `USR-048`, ADR-0050, and
> `docs/mlp/REQUIREMENTS.md` supersede this matrix for the active MLP.

Each row is one independently verifiable obligation. Phase summary prose is not
a substitute for these rows.

Statuses:

- `REVIEW_PENDING`: P00 implementation exists but has not passed the current
  frozen-baseline review.
- `PENDING`: future implementation or terminal verification is not complete.
- `SATISFIED`: the obligation passed its phase-owned verification.
- `WAIVED`: a newer explicit user instruction superseded this one-time
  obligation; the phase evidence records the scope and basis. A waiver does
  not weaken the same requirement in later phases.

## User requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `USR-001` | User | Do not build or require an external supervisor script. | All | Per-phase tracked, packaged, runtime-process, and dependency scans | Phase and final evidence | PENDING |
| `USR-002` | User | Cover every pinned Home Assistant domain through a measured fail-closed capability disposition. | P10, P14 | Pinned domain capability report | ADR-0002 | PENDING |
| `USR-003` | User | Deliver a Home Assistant app/add-on. | P14, P15 | Install and lifecycle tests | ADR-0007 | PENDING |
| `USR-004` | User | Obtain public requirements and contract evidence independently. | P00, P10, P14 | Source ledger review | `docs/clean-room/MATERIALS.yaml` | PENDING |
| `USR-005` | User | Obtain linguistic and evaluation datasets independently. | P02 | Source-admission reports | P02 evidence | WAIVED |
| `USR-006` | User | Meet the independent PT-BR accuracy gate derived from Sophia's public claim. | P15 | Exact-semantic held-out evaluation | ADR-0005 | WAIVED |
| `USR-007` | User | Meet separate core and end-to-end speed gates derived from Sophia's public claims. | P15 | Documented throughput benchmarks | ADR-0005 | PENDING |
| `USR-008` | User | Use only free and open-source project inputs and dependencies. | All | License and ownership audit | ADR-0001 | PENDING |
| `USR-009` | User | Exclude Amazon-specific and Amazon-internal material. | All | Ownership, package, repository, and endpoint scans | `docs/clean-room/USER-DECISIONS.md` | PENDING |
| `USR-010` | User | Limit every phase to three substantive frozen candidate review rounds: one initial round and at most two blocker-remediation rounds. | All | Candidate and review chronology audit | ADR-0006 | PENDING |
| `USR-011` | User | Require the documented minimum acceptance contract for every phase. | All | Mandatory requirement, check, review, finding, and checkpoint gate audit | ADR-0006 | PENDING |
| `USR-012` | User | Checkpoint the first minimally acceptable baseline immediately without optional refinement. | All | First-passing-round checkpoint chronology | Phase evidence | PENDING |
| `USR-013` | User | Defer eligible P3 improvements instead of extending a phase review loop. | All | P3 residual-risk and ownership audit | Review evidence | PENDING |
| `USR-014` | User | Stop a phase as blocked for explicit user scope adjudication when its round budget is exhausted with a P0 through P2 blocker. | All | Exhausted-budget state-transition test | Phase evidence | PENDING |
| `USR-015` | User | Limit remaining P00 work from 2026-08-26 to the current candidate and at most one blocker-only replacement. | P00 | P00 candidate chronology audit | P00 evidence | SATISFIED |
| `USR-016` | User | Permit a deterministic project-authored synthetic PT-BR conformance corpus with labels fixed before NLU implementation, while prohibiting independent-accuracy or Sophia-equivalence claims from it. | P02, P15 | Corpus lineage, freeze chronology, self-oracle rejection, and claim-boundary audit | P02 and P15 evidence | PENDING |
| `USR-017` | User | Permit one P12 evidence-only proof candidate after the three substantive rounds, limited to independently proving the already-implemented generation bindings. | P12 | Candidate chronology, changed-path, production-byte, and reviewer audit | P12 evidence | SATISFIED |
| `USR-018` | User | Permit a documented feasible secret-memory compromise when an admitted FOSS runtime cannot prove that every transient transport-secret copy is individually locked and zeroized. | P13-P15 | Dedicated-peer memory-lock, startup-failure, transient-lifetime, dump, swap, persistence, backup, log, diagnostic, and residual-risk tests | ADR-0019 and P14-P15 evidence | PENDING |
| `USR-019` | User | Permit one consolidated P13 blocker correction after the ordinary source-convergence budget was exhausted. | P13, FINAL | Candidate scope, review chronology, and immediate-checkpoint audit | P13 convergence and review evidence | PENDING |
| `USR-020` | User | Continue to project completion through one bounded P13 source-evidence correction after the `USR-019` subject failed review. | P13, FINAL | Candidate scope, source-byte, and review chronology audit | P13 convergence and review evidence | PENDING |
| `USR-021` | User | Permit one P13 evidence-consistency correction after the `USR-020` subject failed review. | P13, FINAL | Cross-ledger, integrity-window, changed-path, and review audit | P13 convergence and review evidence | PENDING |
| `USR-022` | User | Permit one bounded source-rights workaround using project-authored technical fixtures where external rights cannot be closed. | P13, FINAL | Source-origin, fixture, selected-graph, and changed-path audit | P13 convergence and review evidence | PENDING |
| `USR-023` | User | Permit one compile-only source projection and project-authored Poly1305 technical replacement to close reproduced source blockers. | P13, FINAL | Reachability, source-origin, license, and behavior-equivalence audit | P13 convergence and review evidence | PENDING |
| `USR-024` | User | Permit one P13 evidence-only correction for reproduced origin, notice, and license-election defects. | P13, FINAL | Origin inventory, notice, election, and changed-path audit | P13 convergence and review evidence | PENDING |
| `USR-025` | User | Permit one P13 acquisition and source-evidence closeout while deferring kernel-enforced native Linux proof to P14. | P13, FINAL | Acquisition replay, source identity, claim-boundary, and review audit | P13 convergence and review evidence | PENDING |
| `USR-026` | User | Permit one direct-rustc P13 correction that removes rejected Cargo from validation and closes reproduced source-evidence defects. | P13, FINAL | No-Cargo execution, source replay, identity-window, and review audit | P13 convergence and review evidence | PENDING |
| `USR-027` | User | Permit one P13 validation-identity correction for the defects reproduced on the `USR-026` subject. | P13, FINAL | Executable, ancestor, runtime-library, artifact, and review audit | P13 convergence and review evidence | PENDING |
| `USR-028` | User | Permit one P13 correction for generated-output, sysroot, inherited-Cargo, primary-origin, and notice defects. | P13, FINAL | Output, sysroot, no-Cargo, Git-origin, notice, and review audit | P13 convergence and review evidence | PENDING |
| `USR-029` | User | Permit one P13 correction binding the exact Rust toolchain source and license closure. | P13, FINAL | Toolchain archive, selected-root, license, exclusion, and review audit | P13 convergence and review evidence | PENDING |
| `USR-030` | User | Permit one P13 correction for legal inventory, archive identity, duplicate evidence, and queued-request admission. | P13, FINAL | Inventory, descriptor, cross-ledger, queue, and review audit | P13 convergence and review evidence | PENDING |
| `USR-031` | User | Permit one P13 correction for archive races, legal aliases, request lifetime, and decision-ledger completeness. | P13, FINAL | Archive snapshot, legal discovery, request lifecycle, governance, and review audit | P13 convergence and review evidence | PENDING |
| `USR-032` | User | Permit one P13 correction for verified-byte reopening, destination-ancestor races, and admitted-handler lifetime. | P13, FINAL | Byte-consumption, descriptor-publication, process-containment, and review audit | P13 convergence and review evidence | PENDING |
| `USR-033` | User | Permit one P13 correction for source identity, lazy fetch, archive bounds, cleanup, panic, and scheduler-bound defects. | P13, FINAL | Source replay, archive, cleanup, panic, deadline-claim, and review audit | P13 convergence and review evidence | PENDING |
| `USR-034` | User | Permit one P13 correction for closeout source replay, archive depth, request ordering, legal discovery, and origin disposition. | P13, FINAL | Exact regression, source-evidence, request-state, and review audit | P13 convergence and review evidence | PENDING |
| `USR-035` | User | Permit one P13 correction for archive preflight, selected path-source review, and copied-source rights. | P13, FINAL | Archive, path-source, copied-source, changed-path, and review audit | P13 convergence and review evidence | PENDING |
| `USR-036` | User | Finish P13 through one minimum correction of the six source and governance defects reproduced on `a4a4f904b68447abcc6d24f00fc87b6aba8634f3`, then advance directly to P14 and continue to 100%. | P13, FINAL | FIFO, origin, rights, governance-completeness, changed-scope, and same-subject review audit | ADR-0033 and P13 convergence evidence | PENDING |
| `USR-037` | User | Finish P13 through one consolidated correction of the source-review defects reproduced on `89cb007efc15a67b3f2c9af1af8973a7026538fa`, then advance directly to P14 and continue to 100%. | P13, FINAL | Disposition-precedence, origin-coverage, bounded-output, governance-parser, changed-scope, and same-subject review audit | ADR-0034 and P13 convergence evidence | PENDING |
| `USR-038` | User | After mandatory review of `edf6e2c888c841c423f42a19c110072f3b6f7ec7` reproduced bounded validator and evidence defects, finish P13 through one minimum blocker-only correction and advance directly to P14. | P13, FINAL | Parser, origin, extraction, containment, amplification, lifecycle, changed-scope, and same-subject review audit | ADR-0035 and P13 convergence evidence | PENDING |
| `USR-039` | User | After mandatory review of `95d0eda79737d1be180f69f7560d51e619f84758` reproduced only final bounded source-discovery, governance, and existing-tree verification blockers, finish P13 immediately through one minimum correction and advance directly to P14. | P13, FINAL | Origin, statement-scope, parser, lifecycle, existing-tree-bound, changed-scope, and same-subject review audit | ADR-0036 and P13 convergence evidence | PENDING |
| `USR-040` | User | Keep P13 closed, stop all P13 patches, and advance immediately through the remaining project with the safest bounded workaround where the current host cannot execute a phase gate. | P14, FINAL | Native-gate transfer, disabled-artifact, candidate-freeze, review-scope, and no-refinement audit | ADR-0039 and P14-P15 evidence | PENDING |
| `USR-041` | User | After P14 exhausted its candidate budget with reproduced P0-P2 blockers, permit one exceptional integrated blocker-only correction and continue to 100%. | P14, FINAL | Twelve-finding scope, changed-path, single-freeze, same-subject review, and no-second-correction audit | ADR-0041 and P14 correction evidence | PENDING |
| `USR-042` | User | After all six mandatory reviews of the `USR-041` subject failed, authorize one terminal integrated P14 correction and continue the project. | P14, FINAL | Ten-class scope, changed-path, single-freeze, six-role same-subject review, and terminal-stop audit | ADR-0042 and P14 terminal-correction evidence | PENDING |
| `USR-043` | User | After all six mandatory reviews of the `USR-042` subject failed, authorize one last integrated P14 blocker-remediation pass and then move on. | P14, FINAL | Fourteen-class scope, P13 byte identity, exact regressions, complete gate, single freeze, and six-role same-subject review audit | ADR-0043 and P14 final-remediation evidence | PENDING |
| `USR-044` | User | Move to P15 now without claiming P14 passed. | P14-P15, FINAL | Frozen-baseline, unrun-gate, review-debt, disabled-artifact, and phase-transition audit | ADR-0044 and P14-P15 evidence | PENDING |
| `USR-045` | User | Reopen P14 and P15 after the blocked qualification checkpoint, freeze a fresh untouched project-authored synthetic evaluation lineage before behavior changes, correct the reproduced safety and zero-plan blockers, and continue through native release qualification. | P14-P15, FINAL | Pre-remediation corpus-freeze, sealed-access, changed-scope, inherited-debt, native-runtime, release-gate, review, and terminal audit | ADR-0047 and P14-P15 remediation evidence | PENDING |
| `USR-046` | User | Invalidate P02-v2 after the recorded post-remediation performance-record exposure, freeze a clean P02-v3 lineage before reapplying remediation, and continue through P15, P16, and FINAL. | P15-P16, FINAL | V2 invalidation, v3 pre-implementation freeze, sealed-access, changed-scope, release-gate, review, and terminal audit | ADR-0048 and P15 v3 evidence | PENDING |
| `USR-047` | User | Continue autonomously through P15, P16, and FINAL without further scope prompts; authorize the exhausted P02-v3 blocker-only replacement and all remaining in-scope blocker remediation. | P15-P16, FINAL | Blob-bound source baseline, frozen mutable-I/O scope, sealed-access, native-runtime, release-gate, review, and terminal audit | ADR-0049 and P15-FINAL evidence | PENDING |

## P00 bootstrap requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P00-ROOT-001` | Steering 4 | Record the fresh root without inspecting sibling implementations. | P00 | Seed tree and hash reproduction | `docs/clean-room/ROOT-INVENTORY.md` | SATISFIED |
| `P00-GIT-001` | Steering 5, 13 | Preserve an immutable distributable clean-root commit. | P00 | Root, reachable-object, tree, and fsck checks | `docs/clean-room/ROOT-INVENTORY.md` | SATISFIED |
| `P00-GOV-001` | Steering 13 | Persist repository operating rules. | P00 | Required tracked-path check | `AGENTS.md` | SATISFIED |
| `P00-GOV-002` | Steering 13 | Persist an indexed set of accepted architecture decisions. | P00 | ADR index/status/link validation | `docs/adr/README.md` | SATISFIED |
| `P00-GOV-003` | Steering 11 | Persist mutually consistent project status and autonomous queue. | P00 | Strict YAML and state-invariant tests | Phase state files | SATISFIED |
| `P00-GOV-004` | Steering 13 | Persist a truthful P00 phase report. | P00 | Report/status/queue consistency test | `docs/phases/P00-REPORT.md` | SATISFIED |
| `P00-CR-001` | Steering 4, 6 | Define the clean-room boundary. | P00 | Boundary and exposure review | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-002` | Steering 4 | Define a contamination response. | P00 | Procedure review | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-003` | Steering 4 | Prohibit prior implementations and sibling-directory material. | P00 | Boundary text and path-access audit | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-004` | Steering 4 | Prohibit closed-engine code, binaries, models, vocabulary, private formats, traces, outputs, internal behavior, internal names, and heuristics. | P00 | Boundary and exposure audit | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-005` | Steering 4 | Isolate every suspected contaminated source and derivative. | P00 | Contamination procedure mutation | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-006` | Steering 4 | Identify every commit, datum, rule, test, and report affected by suspected contamination. | P00 | Contamination reachability procedure mutation | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-007` | Steering 4 | Invalidate affected baselines and metrics after contamination. | P00 | Contamination state-transition mutation | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-008` | Steering 4 | Remove contaminated material and every derivative by source ID. | P00 | Selective-removal procedure mutation | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-009` | Steering 4 | Rebuild affected artifacts independently after contamination removal. | P00 | Independent-rebuild procedure mutation | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-CR-010` | Steering 4 | Re-review affected artifacts after contamination removal and rebuild. | P00 | Re-review procedure mutation | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-FOSS-001` | User | Require OSI-approved software licenses. | P00 | Policy and negative fixtures | `docs/clean-room/SOURCE-POLICY.md` | SATISFIED |
| `P00-FOSS-002` | User | Require modifiable and commercially redistributable data licenses. | P00 | Policy and negative fixtures | `docs/clean-room/SOURCE-POLICY.md` | SATISFIED |
| `P00-FOSS-003` | ADR-0001 | License every project-authored code, documentation, script, schema, test, and configuration path as Apache-2.0. | P00-P15 | Tracked/archive path-license audit | `docs/clean-room/DISTRIBUTION-LICENSES.yaml` | PENDING |
| `P00-FOSS-004` | User | Exclude the NOASSERTION steering bytes from current source archives. | P00 | Git tree/archive path check | `LICENSING.md` | SATISFIED |
| `P00-FOSS-005` | User | Exclude the NOASSERTION steering bytes from every distributable Git lineage. | P00 | Reachable-object and clean-clone scan | `LICENSING.md` | SATISFIED |
| `P00-FOSS-006` | ADR-0001 | Treat only operator-supplied OS, kernel, loader, and system libraries as ambient prerequisites. | P00 | Proprietary selected-tool masquerading as ambient negative test | `docs/evidence/TOOLCHAIN-PROVENANCE.yaml` | SATISFIED |
| `P00-FOSS-007` | ADR-0001 | Exclude the ambient host operating system from every project distribution. | P00-P15 | Release-tree, archive, and image provenance audit | Distribution evidence | PENDING |
| `P00-FOSS-008` | ADR-0001 | Do not claim that the ambient host's complete binary composition is open source. | P00-P15 | Release-claim negative test | Release evidence | PENDING |
| `P00-FOSS-009` | ADR-0001 | Do not claim that the ambient host's complete binary composition is reproducible. | P00-P15 | Reproducibility-claim negative test | Release evidence | PENDING |
| `P00-DOC-001` | ADR-0001 | Reject restrictively licensed documentation bytes from tracked project content. | P00-P15 | Provenance and byte-match scan | `docs/clean-room/MATERIALS.yaml` | PENDING |
| `P00-DOC-002` | ADR-0001 | Reject project data transformed from restrictively licensed documentation. | P00-P15 | Derivation-ledger and provenance audit | Phase source evidence | PENDING |
| `P00-DOC-003` | ADR-0001 | Reject restrictively licensed documentation from distributable archives. | P00-P15 | Archive-content scan | Distribution evidence | PENDING |
| `P00-ORCH-001` | ADR-0001 | Keep user orchestration outside tracked and packaged paths. | P00-P15 | Tree and package scan | Clean-room evidence | PENDING |
| `P00-ORCH-002` | ADR-0001 | Prohibit user orchestration as a project dependency. | P00-P15 | Dependency and invocation-graph audit | Phase evidence | PENDING |
| `P00-ORCH-003` | ADR-0001 | Prohibit user orchestration as a data source. | P00-P15 | Source-ledger audit | `docs/clean-room/MATERIALS.yaml` | PENDING |
| `P00-ORCH-004` | ADR-0001 | Prohibit user orchestration as a linguistic authority. | P00-P15 | Rule-provenance audit | Linguistic evidence | PENDING |
| `P00-ORCH-005` | ADR-0001 | Prohibit user orchestration as a validation oracle. | P00-P15 | Test-oracle provenance audit | Phase evidence | PENDING |
| `P00-AMZ-001` | User | Reject Amazon-specific sources regardless of license. | P00 | Negative ownership/source fixtures | `docs/clean-room/SOURCE-POLICY.md` | SATISFIED |
| `P00-AMZ-002` | User | Reject Amazon-internal tools, endpoints, credentials, and data. | P00 | Negative scanner fixtures | `AGENTS.md` | SATISFIED |
| `P00-AMZ-003` | User | Lock every P00 external material and validator tool to the independently approved identity set. | P00 | Canonical ledger digest checks | Governance validator | SATISFIED |
| `P00-SCOPE-001` | Steering 3 | Fix the product as a deterministic local PT-BR NLU. | P00 | Scope ADR review | ADR-0002 | SATISFIED |
| `P00-SCOPE-002` | User | Fix the release vehicle as a Home Assistant add-on. | P00 | Integration ADR review | ADR-0007 | SATISFIED |
| `P00-HA-001` | User | Define broad HA coverage as a pinned capability denominator. | P00 | Coverage contract review | ADR-0002 | SATISFIED |
| `P00-DATA-001` | Steering 6, 8 | Require per-entry provenance for real linguistic material. | P00 | Source policy review | `docs/clean-room/SOURCE-POLICY.md` | SATISFIED |
| `P00-DATA-002` | Steering 6 | Reject AI-origin language from runtime and evaluation artifacts. | P00 | Policy and negative fixture | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-DATA-003` | Steering 6 | Limit `FIXTURE_TECNICA` to opaque non-language markers. | P00 | Fixture-policy and tracked-literal scan | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-DATA-004` | Steering 6 | Exclude `FIXTURE_TECNICA` from linguistic artifacts. | P00 | Linguistic-artifact input scan | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-DATA-005` | Steering 6 | Exclude `FIXTURE_TECNICA` from quality metrics. | P00 | Metric-input scan | `docs/clean-room/BOUNDARY.md` | SATISFIED |
| `P00-REQ-001` | Steering 13 | Give every known requirement a unique owner and oracle. | P00 | Requirement parser and exact manifest comparison | This file | SATISFIED |
| `P00-REQ-002` | Steering 13 | Represent every independently fail-able steering obligation as an atomic requirement row. | P00 | Line-by-line steering traceability review | This file | SATISFIED |
| `P00-DEC-001` | Steering 5.2 | Resolve every decision blocking P01. | P00 | Decision-register check | `docs/phases/OPEN-DECISIONS.md` | SATISFIED |
| `P00-DEC-002` | AGENTS.md | Apply the documented precedence order before resolving a decision conflict. | P00 | Per-level precedence conflict scenarios | `AGENTS.md` | SATISFIED |
| `P00-DEC-003` | AGENTS.md | For same-level conflicts choose the safer, fail-closed, licensed, correct, deterministic, simple, and reversible resolution. | P00 | Per-criterion same-level conflict scenarios | `AGENTS.md` | SATISFIED |
| `P00-BASE-001` | Steering 9, 10 | Define immutable review subjects and evidence-only checkpoints. | P00 | Baseline ADR review | ADR-0006 | SATISFIED |
| `P00-BASE-002` | ADR-0006 | Treat candidate-controlled validation only as defense in depth, never as its own trust anchor. | P00 | Coordinated candidate-validator rewrite test | `docs/evidence/P00-VALIDATION.md` | SATISFIED |
| `P00-BASE-003` | ADR-0006 | Record tuple, tool, SHA-256, report-hash, and reviewer-instance authenticity as external review assumptions. | P00 | Per-assumption deletion mutations | `docs/evidence/P00-VALIDATION.md` | SATISFIED |
| `P00-TOOL-001` | User | Record version, source, license, owner, purpose, and identity for each required validator tool. | P00 | Toolchain schema and runtime identity checks | `docs/evidence/TOOLCHAIN-PROVENANCE.yaml` | SATISFIED |
| `P00-TOOL-002` | User | Record rightsholders, license scope, obligations, modification rights, redistribution rights, and independent review roles for every required validator tool. | P00 | Tool rights-evidence schema and review | `docs/evidence/TOOLCHAIN-PROVENANCE.yaml` | SATISFIED |
| `P00-VAL-001` | Steering 6.4 | Bind validation to an expected clean commit and tree. | P00 | Validator positive and negative tests | `tools/validate-governance.rb` | SATISFIED |
| `P00-VAL-002` | Steering 6.4 | Reject malformed or contradictory governance state. | P00 | Negative regression suite | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-003` | Steering 6.4 | Reject skip-worktree and assume-unchanged index state. | P00 | Index-flag negative tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-004` | Steering 6.4 | Reject binary payloads. | P00 | Binary payload mutation test | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-005` | Steering 6.4 | Sanitize the process environment before Ruby startup through byte-bound required launchers. | P00 | Preload-forgery and launcher mutation tests | `tools/validate-governance` | SATISFIED |
| `P00-VAL-006` | ADR-0006 | Require a reviewer-owned out-of-tree tuple that pins commit, tree, normative rows, and both validator launcher/source pairs. | P00 | Missing, malformed, and substituted tuple tests | `tools/validate-governance.rb` | SATISFIED |
| `P00-VAL-007` | ADR-0006 | Verify committed modes and hashes against the review tuple before executing repository code. | P00 | Attested external preflight reproduction | `docs/evidence/P00-VALIDATION.md` | SATISFIED |
| `P00-VAL-008` | ADR-0006 | Require every executing validator launcher and source to be a canonical-path regular file byte-equal to its committed blob. | P00 | Dirty, symlink, copied-path, mode, and byte mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-009` | ADR-0006 | Revalidate the exact reviewed subject and original tuple before validating its checkpoint. | P00 | Subject and tuple substitution tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-010` | Steering 6.4 | Reject invalid UTF-8 payloads. | P00 | Invalid UTF-8 mutation test | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-011` | Steering 6.4 | Reject YAML aliases. | P00 | YAML alias mutation test | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-012` | Steering 6.4 | Reject semantically colliding YAML keys. | P00 | Semantic-key mutation tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-013` | ADR-0006 | Bind each P00 checkpoint report to a reviewer-owned SHA-256 supplied outside the candidate. | P00 | Report substitution and missing-tuple tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-014` | ADR-0006 | Require exactly five pairwise-distinct P00 reviewer-instance identifiers. | P00 | Missing and reused-instance checkpoint mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-015` | ADR-0006 | Reject an empty checkpoint report section. | P00 | Empty-section checkpoint mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-016` | ADR-0006 | Limit every non-report checkpoint file to its canonical byte transformation. | P00 | Per-file checkpoint mutation tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-017` | ADR-0006 | Recompute normative-row SHA-256 in document order from the exact six ADR-defined UTF-8 fields and byte delimiters using reviewer-owned instructions. | P00 | Independent recomputation plus field, order, and delimiter mutations | `docs/evidence/P00-VALIDATION.md` | SATISFIED |
| `P00-VAL-018` | ADR-0006 | Exclude Status from the normative-row digest and bind it through a separate lifecycle digest. | P00 | Status-only and normative-field mutation tests | `docs/evidence/REQUIREMENTS-MANIFEST.yaml` | SATISFIED |
| `P00-VAL-019` | ADR-0006 | Run external preflight with the attested absolute Git executable before candidate code. | P00 | PATH, executable, and Git-identity substitutions | P00 review evidence | SATISFIED |
| `P00-VAL-020` | ADR-0006 | Run external preflight with the attested absolute Ruby executable before candidate code. | P00 | PATH, executable, and Ruby-identity substitutions | P00 review evidence | SATISFIED |
| `P00-VAL-021` | ADR-0006 | Perform external preflight in a private clone containing no hardlinks to the candidate worktree. | P00 | Hardlink, inode, and clone-location negatives | P00 review evidence | SATISFIED |
| `P00-VAL-022` | ADR-0006 | Require the evidence checkpoint's sole parent to be the reviewed subject. | P00 | Wrong-parent and merge-commit tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-023` | ADR-0006 | Require every checkpoint tree entry to use a permitted regular-file mode. | P00 | Symlink, gitlink, and mode mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-024` | ADR-0006 | Bind checkpoint validation to the subject commit, subject tree, and checkpoint commit. | P00 | Missing and substituted identity tests | P00 checkpoint evidence | SATISFIED |
| `P00-VAL-025` | ADR-0006 | Reject a checkpoint report containing contradictory verdicts. | P00 | Contradictory-verdict checkpoint mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-026` | ADR-0006 | Reject a checkpoint report containing an unresolved finding in raw, decoded, hidden-comment, invalid-link, or rendered Markdown text. | P00 | Raw, encoded, HTML-comment, invalid-link, and rendered unresolved-finding checkpoint mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-027` | ADR-0006 | Require a new subject baseline and every affected re-review after a non-evidence-only checkpoint change. | P00 | Substantive-change and stale-report mutations | P00 checkpoint evidence | SATISFIED |
| `P00-VAL-028` | ADR-0006 | Permit `REVIEW_PENDING` during P00 only for requirements owned exclusively by P00. | P00 | Cross-phase lifecycle mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-029` | ADR-0006 | Keep cross-phase requirements pending through the P00 evidence checkpoint. | P00 | Premature-satisfaction checkpoint mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-030` | ADR-0006 | Reject semantically duplicate escaped keys in structured checkpoint-report payloads. | P00 | Escaped duplicate-key checkpoint mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-031` | ADR-0006 | Bind the project `last_validation` timestamp to the P00 validation evidence timestamp. | P00 | Stale-timestamp mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-032` | ADR-0006 | Reject checkpoint-report bytes before or after the canonical report schema. | P00 | Prefix and suffix finding mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-033` | ADR-0006 | Normalize assignment-like sensitive keys across snake, kebab, dotted, and camel case. | P00 | Unfenced camel-case sensitive-assignment mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-034` | ADR-0006 | Fail closed when a nested structured payload exceeds the admitted fragment limit. | P00 | Nested fragment-overflow checkpoint mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-035` | ADR-0006 | Reject NUL bytes in every checkpoint evidence report. | P00 | NUL-bearing checkpoint-report mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-036` | ADR-0006 | Normalize Markdown quote, list, and indentation prefixes before checking findings and verdicts. | P00 | Markdown control-prefix checkpoint mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-037` | ADR-0006 | Require inspected paths and input/result evidence fields in their canonical first positions. | P00 | Scope-preamble and evidence-order mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-038` | ADR-0006 | Canonicalize structured sensitive keys independently of escapes, separators, and acronym casing. | P00 | Escaped acronym-key checkpoint mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-039` | ADR-0006 | Decode encoded source identifiers until stable or reject them at a bounded fail-closed limit. | P00 | Exact 64-pass positives and 65-pass percent/text limit negatives | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-040` | ADR-0006 | Reject malformed checkpoint requirement rows with a specific validation error. | P00 | Malformed checkpoint-ID mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-041` | ADR-0006 | Decode percent, JSON Unicode, HTML-entity, and Markdown report controls before checking verdict and severity tokens. | P00 | Encoded report-control checkpoint mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-042` | ADR-0006 | Require the first decoded Scope line to consist of `Paths:` and exactly one nonempty single-line code span. | P00 | Literal/encoded multiple spans and carriage-return mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-043` | Steering 6.4 | Decode unfenced assignment keys before checking for credentials and residential data. | P00 | Percent, JSON Unicode, and HTML assignment mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-044` | User | Resolve encoded URI dot segments before admitting a repository owner. | P00 | Encoded owner-changing dot-segment mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-045` | Steering 6.4 | Bound YAML AST and value traversal and convert top-level, assignment, whole-payload, or recursively embedded parser errors and stack exhaustion to validation failures. | P00 | Subject/checkpoint AST and semantic-value tests plus malformed explicit/embedded payload and strict, assignment, whole-payload, and embedded stack-exhaustion tests | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-046` | User | Inspect canonical provider, owner, and upstream-owner fields inside structured JSON. | P00 | Encoded nested-provider JSON mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-047` | Steering 6.4 | Scan valid Markdown YAML fences with zero to three leading spaces and backtick or tilde markers of length three or greater. | P00 | Indented long-marker backtick and tilde duplicate-key mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-048` | Steering 6.4 | Exempt residential values only when the complete scalar string is the exact technical fixture marker. | P00 | Fixture-prefix, comment, mixed-array, fixture-only-array, and exact-scalar cases | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-049` | Steering 6.4 | Remove Unicode default-ignorable code points from every decoded security scan view before matching controls, sensitive keys, providers, packages, URLs, and repository owners. | P00 | Literal and encoded default-ignorable scanner mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-050` | User | Require canonical structured provider, owner, and upstream-owner metadata values to be nonempty strings. | P00 | Mapping, array, and boolean provider-value mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-051` | User | Inspect every overlapping URL scheme start with byte-correct offsets under fixed candidate-count and candidate-byte limits. | P00 | Nested blocked URL, multibyte-prefix URL, and both URL-limit mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-052` | Steering 6.4 | Discover embedded JSON in one bounded pass with fixed candidate-count, nesting-depth, and fragment-count limits. | P00 | Candidate/fragment overflow, nesting-depth, and malformed-wrapper mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-053` | ADR-0006 | Reject checkpoint review reports above a fixed byte limit before materializing committed or worktree report bytes. | P00 | Oversized committed-blob and worktree-bound checkpoint mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-054` | ADR-0006 | Preserve rendered Markdown autolink labels while normalizing checkpoint report controls. | P00 | Autolink-wrapped contradictory-verdict mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-055` | Steering 6.4 | Recognize bounded non-whitespace credential assignment values including Markdown inline code. | P00 | Inline-code credential-value mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-056` | User | Bound recursive structured provider traversal and fail closed when the limit is exceeded. | P00 | Provider-depth-limit mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-057` | Steering 6.4 | Scan raw, decoded, and linearly bounded Markdown-visible normalized views for credential and residential assignment keys. | P00 | Subject/checkpoint emphasis, balanced links, inline/reference/shortcut images, code-wrapped keys, and matched/unmatched nesting limits | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-058` | Steering 6.4 | Compute a residential YAML fixture exemption from the complete valid parsed scalar, including continuation lines, and reject prefixed or malformed continuations. | P00 | Subject/checkpoint valid, prefixed, and malformed continuation mutations plus block, folded, literal, flow, sibling, quoted, multiline, and commented exact-fixture positives | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-059` | Steering 6.4 | Scan Markdown YAML fences when the first info-string token is `yaml` or `yml`, including fences with following attributes and LF, CRLF, or CR line endings. | P00 | Backtick, tilde, attributed, and lone-CR YAML-fence mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-060` | User | Apply blocked-provider structural checks to every parsed YAML or JSON value, recurse into bounded structured strings, and fail closed on malformed structured candidates. | P00 | Fenced-YAML non-scalar provider plus valid or malformed serialized JSON and inline/standalone sequence, flow, explicit, comment-prefixed, or multi-document YAML mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-061` | ADR-0006 | Compare every tracked regular-file worktree byte sequence directly with its subject or checkpoint blob without relying on Git status, index refresh, or stat-cache settings. | P00 | Same-size dirty subject/checkpoint mutations under weak Git stat configuration | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-062` | ADR-0006 | Reject an oversized checkpoint review report by metadata before Git whitespace checks, private-clone construction, or the validator reading committed or worktree report bytes. | P00 | Oversized trailing-whitespace report with externally supplied report hashes and error-precedence mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-063` | ADR-0006 | Isolate every regression-harness Git subprocess from system, global, environment-injected, replacement-object, alternate-object, and worktree/index configuration. | P00 | Forced-signing system-config invocation and subprocess-environment regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-064` | Steering 6.4 | Treat an explicit YAML document marker as a strict structured candidate and convert parser errors or stack exhaustion to validation failures. | P00 | Malformed explicit-document and stubbed whole-payload stack-exhaustion regressions | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-065` | User | Reject a malformed JSON fragment when a decoded canonical credential, residential, provider, owner, or upstream-owner key identifies it as protected structured data. | P00 | Subject and checkpoint trailing-comma provider regressions | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-066` | ADR-0006 | Strip rendered HTML and distinguish visible autolinks with quote-aware linear scanning so malformed openers, quoted greater-than signs, or line breaks cannot split or exhaust checkpoint controls. | P00 | Quoted-attribute, multiline HTML, and instrumented unmatched-autolink linearity regressions | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-067` | Steering 6.4 | Reject non-string semantic keys after recursively embedded YAML is safely loaded. | P00 | Boolean semantic-key provider-collision regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-068` | Steering 6.4 | Skip escaped Markdown delimiter openers in one forward pass without invoking suffix delimiter matching. | P00 | Instrumented escaped-opener linearity regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-069` | ADR-0006 | Decode valid JSON UTF-16 surrogate pairs into one valid Unicode scalar without leaking an internal encoding error. | P00 | Surrogate-pair decoding regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-070` | Steering 6.4 | Decode quoted YAML scalar mapping keys before canonical protected-key classification and never suppress structural parsing solely because a broader canonical key resembles a dedicated assignment. | P00 | YAML hexadecimal-escape and canonical-separator credential-key regressions | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-071` | ADR-0006 | Preserve a malformed outer HTML tag when an unquoted nested opener appears before its close so the nested tag cannot consume a finding or verdict token. | P00 | Nested malformed-HTML checkpoint finding regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-072` | Steering 6.4 | Classify a malformed JSON key containing a lone UTF-16 surrogate escape as protected when removing only invalid surrogate escapes yields a canonical protected key. | P00 | Lone-surrogate protected credential-key regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-073` | ADR-0006 | Terminate an unmatched Markdown angle destination at a nested opener or line ending and keep repeated malformed destinations linear. | P00 | Instrumented malformed-angle byte-read budget regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-074` | Steering 6.4 | Do not classify a leading Markdown link, reference, image, or shortcut label as a strict whole YAML sequence solely because it begins with an opening bracket. | P00 | Leading Markdown-link protected-key false-positive regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-075` | Steering 6.4 | Normalize parsed structured keys through bounded rendered Markdown and HTML visibility before protected-key classification. | P00 | Inline-link, reference-link, image, HTML-tag, and HTML-comment provider-key mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-076` | Steering 6.4 | Convert YAML mapping-key safe-load stack exhaustion into a bounded governance validation failure. | P00 | Stubbed mapping-key safe-load stack-exhaustion regression | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-077` | ADR-0006 | Reject copied validator launcher or source execution even when copied bytes match the frozen review tuple. | P00 | Copied launcher/source canonical-path mutation | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-078` | User, GLB-PRIV-009 | Scan every bounded non-exempt blob and every entry of every tree reachable from any project ref, preserve all refs during checkpoint revalidation, and do not limit privacy checks to reviewed ancestry or commit diffs. | P00 | Alternate-branch content, direct-tree path, merge-result path, and checkpoint tag-ref mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-079` | ADR-0006 | Remove complete rendered HTML declarations, processing instructions, and CDATA from checkpoint control text while preserving visible URI and email autolinks. | P00 | Hidden-control declaration, processing-instruction, CDATA, and visible-autolink regressions | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-VAL-080` | ADR-0006 | Reject every repeated validator command-line option before constructing the subject or checkpoint tuple. | P00 | Duplicate subject and checkpoint option mutations | `tools/test-validate-governance.rb` | SATISFIED |
| `P00-REV-001` | Steering 9 | Obtain requirements review on one P00 baseline. | P00 | Exact PASS report | P00 review evidence | WAIVED |
| `P00-REV-002` | Steering 9 | Obtain correctness review on one P00 baseline. | P00 | Exact PASS report | P00 review evidence | WAIVED |
| `P00-REV-003` | Steering 9 | Obtain tests review on one P00 baseline. | P00 | Exact PASS report | P00 review evidence | WAIVED |
| `P00-REV-004` | Steering 9 | Obtain risk review on one P00 baseline. | P00 | Exact PASS report | P00 review evidence | WAIVED |
| `P00-REV-005` | Steering 9 | Obtain reproducibility review on one P00 baseline. | P00 | Exact PASS report | P00 review evidence | WAIVED |

## Global product requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `GLB-TEXT-001` | Steering 3, 6 | Preserve original input bytes unchanged. | P01, P04 | Byte equality properties | P04 evidence | SATISFIED |
| `GLB-TEXT-002` | Steering 3, 6 | Represent boundary offsets as checked half-open UTF-8 byte spans. | P01, P04 | Boundary and range tests | P04 evidence | SATISFIED |
| `GLB-TEXT-003` | Steering 6 | Never apply global accent removal. | P04 | Metamorphic normalization tests | P04 evidence | SATISFIED |
| `GLB-LING-001` | Steering 6 | Give every language rule an admitted origin. | P02, P05-P09 | Rule provenance audit | Linguistic review evidence | PENDING |
| `GLB-LING-002` | Steering 6 | Preserve justified lexical and syntactic ambiguity. | P07-P09 | Ambiguity cases | Linguistic review evidence | PENDING |
| `GLB-LING-003` | Steering 6 | Keep unknown linguistic facts unknown. | P05-P09 | Unknown-token negatives | Linguistic review evidence | PENDING |
| `GLB-INTENT-001` | Steering 3 | Recognize one typed intent with span evidence. | P09 | Exact intent/slot tests | P09 evidence | PENDING |
| `GLB-INTENT-002` | Steering 3 | Recognize multiple commands as a typed graph. | P11 | Exact graph tests | P11 evidence | SATISFIED |
| `GLB-ENTITY-001` | Steering 3 | Resolve entities by stable identifiers. | P10 | Entity identity tests | P10 evidence | SATISFIED |
| `GLB-ENTITY-002` | Steering 3 | Clarify entity ties instead of selecting by position. | P10 | Collision tests | P10 evidence | SATISFIED |
| `GLB-SESSION-001` | Steering 3 | Isolate short-term context by opaque session identifier. | P12 | Cross-session tests | P12 evidence | SATISFIED |
| `GLB-SESSION-002` | Steering 3 | Bound session state by an explicit TTL. | P12 | Expiry boundary tests | P12 evidence | SATISFIED |
| `GLB-SESSION-003` | Steering 3 | Bound every session-state collection by an explicit count limit. | P12 | Collection resource tests | P12 evidence | SATISFIED |
| `GLB-SAFE-001` | Steering 3, 6 | Abstain when evidence is insufficient. | P09-P14 | Insufficient-evidence negatives | P16 evidence | PENDING |
| `GLB-SAFE-002` | Steering 3, 6 | Clarify resolvable ambiguity. | P09-P14 | Clarification oracle | P16 evidence | PENDING |
| `GLB-SAFE-003` | Steering 6 | Never turn an error into a speculative plan. | P01-P14 | Error-path properties | P16 evidence | PENDING |
| `GLB-OFFLINE-001` | Steering 3 | Keep normal runtime offline. | P13-P15 | Network-denied runtime | P15 evidence | PENDING |
| `GLB-OFFLINE-002` | Steering 3 | Permit Home Assistant access only inside the two-part `ha-adapter` subsystem. | P13-P15 | Process/call-graph checks | P15 evidence | PENDING |
| `GLB-NOLLM-001` | Steering 3 | Exclude runtime LLMs. | All | Dependency and process audit | Final evidence | PENDING |
| `GLB-NOLLM-002` | Steering 3 | Exclude silent online learning. | All | State mutation audit | Final evidence | PENDING |
| `GLB-SOPHIA-001` | User, AGENTS.md | Classify every Sophia public product claim as untrusted comparison context and prohibit it from serving as linguistic, implementation, model, rule, gold, or evaluation input. | All | Source-role allowlist, lineage audit, and prohibited-use mutations | Phase evidence | PENDING |
| `GLB-DATA-001` | AGENTS.md, SOURCE-POLICY.md | Reject model-generated, AI-translated, or unprovenanced language from linguistic artifacts except the exact provenance-bound `PROJECT_AUTHORED_SYNTHETIC` corpus authorized by `USR-016`. | All | Per-phase lineage audit, exception-scope checks, and prohibited-origin mutations | Phase evidence | PENDING |
| `GLB-CR-001` | AGENTS.md, BOUNDARY.md | Prohibit inspection or use of prior implementations and sibling-directory material throughout every phase. | All | Per-phase path-access and source-lineage audit | Phase evidence | PENDING |
| `GLB-CR-002` | AGENTS.md, BOUNDARY.md | Prohibit inspection or use of a closed engine's code, binaries, models, vocabulary, private formats, traces, outputs, internal behavior, internal names, and heuristics throughout every phase. | All | Per-phase exposure and source-lineage audit | Phase evidence | PENDING |
| `GLB-SCOPE-001` | Steering 3 | Keep speech-to-text processing outside the NLU core. | P01, P13-P15 | Dependency, process, and package-boundary audit | Final evidence | PENDING |
| `GLB-SCOPE-002` | Steering 3 | Keep text-to-speech processing outside the NLU core. | P01, P13-P15 | Dependency, process, and package-boundary audit | Final evidence | PENDING |
| `GLB-SCOPE-003` | Steering 3 | Exclude general-purpose personal memory from the NLU product. | P01, P12-P15 | State-schema, persistence, and process audit | Final evidence | PENDING |
| `GLB-SCOPE-004` | Steering 3 | Exclude open-domain response generation from the NLU product. | P01, P14-P15 | Renderer schema, dependency, and output audit | Final evidence | PENDING |
| `GLB-FIX-001` | Steering 6.1 | Label every technical fixture `FIXTURE_TECNICA`. | All | Tracked fixture-label scan | Phase evidence | PENDING |
| `GLB-FIX-002` | Steering 6.1 | Limit technical fixtures to opaque non-language markers. | All | Fixture-content provenance audit | Phase evidence | PENDING |
| `GLB-FIX-003` | Steering 6.1 | Exclude technical fixtures from linguistic artifacts. | All | Linguistic-artifact input scan | Phase evidence | PENDING |
| `GLB-FIX-004` | Steering 6.1 | Exclude technical fixtures from quality metrics. | All | Metric-input scan | Phase evidence | PENDING |
| `GLB-EVAL-001` | Steering 6.1 | Isolate the final evaluation set from tuning and model selection. | P02-P15 | Access and chronology audit | P15 evidence | PENDING |
| `GLB-EVAL-002` | Steering 4.2, USR-016 | Never treat project NLU output as a gold label or evaluation oracle; project-authored expected semantics must be fixed by the generator specification before NLU implementation. | P02-P16 | Generator chronology, oracle-lineage, and self-output rejection audit | P16 evidence | PENDING |
| `GLB-METRIC-001` | Steering 6.1 | Report the domain for every metric. | P07-P16 | Metric-report schema | Phase evidence | PENDING |
| `GLB-METRIC-002` | Steering 6.1 | Report the dataset identity for every metric. | P07-P16 | Metric-report schema | Phase evidence | PENDING |
| `GLB-METRIC-003` | Steering 6.1 | Report the dataset version for every metric. | P07-P16 | Metric-report schema | Phase evidence | PENDING |
| `GLB-METRIC-004` | Steering 6.1 | Report the split identity for every metric. | P07-P16 | Metric-report schema | Phase evidence | PENDING |
| `GLB-METRIC-005` | Steering 6.1 | Report limitations for every metric. | P07-P16 | Metric-report schema | Phase evidence | PENDING |
| `GLB-OUTCOME-001` | ADR-0002 | Expose exactly four mutually exclusive outcomes: typed plan, clarification, abstention, or protocol error. | P01 | Exhaustive type/schema and unknown-tag tests | P01 evidence | SATISFIED |
| `GLB-DET-001` | Steering 6.2 | Produce identical semantics for identical explicit inputs. | P01-P16 | Repetition tests across core and both adapter halves | Determinism evidence | PENDING |
| `GLB-DET-002` | Steering 6.2 | Produce identical serialized bytes for identical values. | P01-P16 | Byte snapshots across core and both adapter halves | Determinism evidence | PENDING |
| `GLB-DET-003` | Steering 6.2 | Keep runtime semantic behavior independent of ambient entropy. | P01-P16 | Entropy-denied runtime tests | Determinism evidence | PENDING |
| `GLB-DET-004` | Steering 6.2 | Fix every offline training seed, configuration, and environment. | P08-P15 | Two-training artifact comparison | Determinism evidence | PENDING |
| `GLB-DET-005` | ADR-0008 | Report semantic, adapter, build, and measurement envelopes separately. | P15-P16, FINAL | Exact named-section report schema | Determinism evidence | PENDING |
| `GLB-DET-006` | ADR-0008 | Name the applicable envelope and its complete explicit input set in every release reproducibility claim. | P15, FINAL | Release-claim schema and omission mutations | Final evidence | PENDING |
| `GLB-SEM-001` | ADR-0008 | Given identical binary, configuration, language package, catalog-snapshot revision, session snapshot, injected logical time, and request bytes, produce the identical core value. | P01-P16 | Exact-input replay and core-value comparison | Determinism evidence | PENDING |
| `GLB-SEM-002` | ADR-0008 | Given identical semantic-envelope inputs, produce identical serialized bytes. | P01-P16 | Exact-input replay and byte comparison | Determinism evidence | PENDING |
| `GLB-SEM-003` | AGENTS.md | Exclude timestamps, including injected logical or monotonic time values, from semantic results and serialized semantic-result bytes. | P01-P16 | Schema denial and injected-time serialization tests | Determinism evidence | PENDING |
| `GLB-SEM-004` | AGENTS.md | Exclude host filesystem paths from semantic results and serialized semantic-result bytes. | P01-P16 | Schema denial and path-sentinel serialization tests | Determinism evidence | PENDING |
| `GLB-SEM-005` | AGENTS.md | Exclude random identifiers from semantic results and serialized semantic-result bytes. | P01-P16 | Schema denial and random-ID sentinel tests | Determinism evidence | PENDING |
| `GLB-SEM-006` | AGENTS.md | Exclude locale-dependent values from semantic results and serialized semantic-result bytes. | P01-P16 | Locale-permutation schema and byte tests | Determinism evidence | PENDING |
| `GLB-SEM-007` | AGENTS.md | Serialize semantic mappings in canonical key order independently of unordered-map iteration order. | P01-P16 | Map-insertion permutation byte tests | Determinism evidence | PENDING |
| `GLB-ADAPT-001` | ADR-0008 | Treat policy state as an explicit adapter-envelope input. | P13-P16 | Policy-state substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-002` | ADR-0008 | Treat catalog generation as an explicit adapter-envelope input. | P13-P16 | Catalog-generation substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-003` | ADR-0008 | Treat the Home Assistant API transcript as an explicit adapter-envelope input. | P13-P16 | API-transcript substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-004` | ADR-0008 | Treat pairing-key epoch as an explicit adapter-envelope input. | P13-P16 | Pairing-epoch substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-005` | ADR-0008 | Treat the authenticated-channel transcript as an explicit adapter-envelope input. | P13-P16 | Channel-transcript substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-006` | ADR-0008 | Treat caller context as an explicit adapter-envelope input. | P13-P16 | Caller-context substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-007` | ADR-0008 | Treat idempotency state as an explicit adapter-envelope input. | P13-P16 | Idempotency-state substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-008` | ADR-0008 | Treat injected monotonic time as an explicit adapter-envelope input. | P13-P16 | Monotonic-time substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-009` | ADR-0008 | Treat deadlines as explicit adapter-envelope inputs. | P13-P16 | Deadline substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-010` | ADR-0008 | Treat scheduling events as explicit adapter-envelope inputs. | P13-P16 | Schedule substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-011` | ADR-0008 | Treat cancellation events as explicit adapter-envelope inputs. | P13-P16 | Cancellation substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-012` | ADR-0008 | Treat timeout events as explicit adapter-envelope inputs. | P13-P16 | Timeout substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-013` | ADR-0008 | Treat reconnect events as explicit adapter-envelope inputs. | P13-P16 | Reconnect substitution test | Determinism evidence | PENDING |
| `GLB-ADAPT-014` | ADR-0008 | Given the same validated plan and adapter-envelope inputs, issue the same ordered external request sequence. | P13-P16 | Repeated execution of both adapter halves | Determinism evidence | PENDING |
| `GLB-ADAPT-015` | ADR-0008 | Given the same validated plan and adapter-envelope inputs, return the same typed result. | P13-P16 | Repeated execution and typed-result comparison | Determinism evidence | PENDING |
| `GLB-ADAPT-016` | ADR-0008 | Inject nonce generation as an explicit adapter security input. | P13-P14 | Deterministic nonce fake and source audit | Determinism evidence | PENDING |
| `GLB-ADAPT-017` | ADR-0008 | Inject credential generation as an explicit adapter security input. | P13-P14 | Deterministic credential fake and source audit | Determinism evidence | PENDING |
| `GLB-ADAPT-018` | ADR-0008 | Model live Home Assistant outcomes only as explicit in-memory transcript inputs. | P14-P16 | Transcript replay and persistence canaries | Determinism evidence | PENDING |
| `GLB-ADAPT-019` | ADR-0008 | Exercise every stateful session and adapter component under deterministic concurrency or model-checking schedules. | P12-P14, P16 | Schedule replay and state/result comparison | Determinism evidence | PENDING |
| `GLB-BUILD-001` | ADR-0008 | Produce byte-identical per-target artifacts in separate clean paths. | P01, P03-P16 | Two clean offline builds in distinct absolute directories with archive and image digest comparison | Determinism evidence | PENDING |
| `GLB-BUILD-002` | ADR-0008 | Fix `SOURCE_DATE_EPOCH` as an explicit reproducible-build input. | P01, P03-P16 | Value-presence, mutation, and artifact-comparison tests | Determinism evidence | PENDING |
| `GLB-BUILD-IN-001` | ADR-0008 | Bind every reproducible build to an immutable source identity. | P01, P03-P16 | Source-identity substitution test | Determinism evidence | PENDING |
| `GLB-BUILD-IN-002` | ADR-0008 | Bind every reproducible build to immutable tool identities. | P01, P03-P16 | Tool-identity substitution test | Determinism evidence | PENDING |
| `GLB-BUILD-IN-003` | ADR-0008 | Bind every reproducible build to immutable dependency identities. | P01, P03-P16 | Dependency-identity substitution test | Determinism evidence | PENDING |
| `GLB-BUILD-IN-004` | ADR-0008 | Bind every reproducible build to immutable data identities. | P03-P16 | Data-identity substitution test | Determinism evidence | PENDING |
| `GLB-BUILD-IN-005` | ADR-0008 | Bind every reproducible build to explicit build arguments. | P01, P03-P16 | Build-argument substitution test | Determinism evidence | PENDING |
| `GLB-BUILD-IN-006` | ADR-0008 | Bind every reproducible build to one target identity. | P01, P03-P16 | Target-identity substitution test | Determinism evidence | PENDING |
| `GLB-BUILD-003` | ADR-0008 | Normalize embedded build paths in reproducible artifacts. | P01, P03-P16 | Distinct-root builds and embedded-path scan | Determinism evidence | PENDING |
| `GLB-BUILD-004` | ADR-0008 | Normalize archive member order in reproducible artifacts. | P01, P03-P16 | Permuted-input archive comparison | Determinism evidence | PENDING |
| `GLB-BUILD-005` | ADR-0008 | Normalize archive ownership metadata in reproducible artifacts. | P01, P03-P16 | Differing UID/GID build comparison | Determinism evidence | PENDING |
| `GLB-BUILD-006` | ADR-0008 | Normalize build locale for reproducible artifacts. | P01, P03-P16 | Locale-permuted build comparison | Determinism evidence | PENDING |
| `GLB-BUILD-007` | ADR-0008 | Normalize build timezone for reproducible artifacts. | P01, P03-P16 | Timezone-permuted build comparison | Determinism evidence | PENDING |
| `GLB-BUILD-008` | ADR-0008 | Normalize every OCI timestamp from `SOURCE_DATE_EPOCH`. | P15-P16 | OCI manifest, config, and layer timestamp audit | Determinism evidence | PENDING |
| `GLB-BUILD-009` | ADR-0008 | Compare reproducibility only between artifacts built for the same target architecture. | P15-P16 | Cross-target rejection and same-target baseline tests | P15 evidence | PENDING |
| `GLB-SEC-001` | Steering 6.3 | Separate interpretation from policy. | P01, P13 | Dependency/call-boundary tests | Security evidence | PENDING |
| `GLB-SEC-002` | Steering 6.3 | Separate policy from execution. | P13, P14 | Dependency/call-boundary tests | Security evidence | PENDING |
| `GLB-SEC-003` | Steering 6.3 | Keep credentials out of core. | P13, P14 | Sentinel credential test | Security evidence | PENDING |
| `GLB-SEC-004` | Steering 6.3 | Keep credentials out of server processes. | P13, P14 | Environment sentinel test | Security evidence | PENDING |
| `GLB-SEC-005` | Steering 6.3 | Revalidate every plan at the adapter boundary. | P14 | Tampered/stale plan tests | P14 evidence | PENDING |
| `GLB-SEC-006` | Steering 6.3 | Deny unsupported actions by default. | P13, P14 | Policy matrix negatives | P14 evidence | PENDING |
| `GLB-SEC-007` | Steering 6.3 | Require explicit confirmation for sensitive actions. | P12-P14 | Confirmation tests | P14 evidence | PENDING |
| `GLB-SEC-008` | Steering 6.3 | Bound parser execution time. | P04, P13, P16 | Deadline and exhaustion tests | P16 evidence | PENDING |
| `GLB-SEC-009` | Steering 6.3 | Prevent external input from causing a panic. | P01-P16 | Panic-free fuzz and property tests | P16 evidence | PENDING |
| `GLB-SEC-010` | Steering 6.3 | Prevent external input from causing an unbounded loop. | P01-P16 | Deadline and exhaustion tests | P16 evidence | PENDING |
| `GLB-SEC-011` | Steering 6.3 | Prevent external input from causing an unbounded allocation. | P01-P16 | Allocation-limit tests | P16 evidence | PENDING |
| `GLB-SEC-012` | Steering 6.3 | Bound parser allocation independently of process-wide allocation limits. | P04, P13, P16 | Parser-allocation boundary tests | P16 evidence | PENDING |
| `GLB-SEC-013` | ADR-0002 | Classify every unlock operation as sensitive and require explicit policy confirmation. | P02, P12-P14 | Risk-model exactness and unlock confirmation tests | P02 and P14 evidence | PENDING |
| `GLB-SEC-014` | ADR-0002 | Classify every access-control opening operation as sensitive and require explicit policy confirmation. | P02, P12-P14 | Risk-model exactness and access-opening confirmation tests | P02 and P14 evidence | PENDING |
| `GLB-SEC-015` | ADR-0002 | Classify every alarm-disable operation as sensitive and require explicit policy confirmation. | P02, P12-P14 | Risk-model exactness and alarm-disable confirmation tests | P02 and P14 evidence | PENDING |
| `GLB-SEC-016` | ADR-0002 | Classify every safety-affecting device-control operation as sensitive and require explicit policy confirmation. | P02, P12-P14 | Risk-model exactness and safety-control confirmation tests | P02 and P14 evidence | PENDING |
| `GLB-SEC-017` | AGENTS.md | Keep response rendering in a component boundary separate from interpretation, policy, and execution. | P01, P13-P14 | Dependency and call-boundary tests across all four components | Security evidence | PENDING |
| `GLB-LOG-001` | Steering 6.3 | Emit structured bounded logs. | P13, P14 | Logging tests | P14 evidence | PENDING |
| `GLB-LOG-002` | Steering 6.3 | Redact credentials from diagnostics. | P13-P15 | Credential sentinel leak tests | P15 evidence | PENDING |
| `GLB-LOG-003` | Steering 6.3 | Redact residential data from diagnostics. | P13-P15 | Residential sentinel leak tests | P15 evidence | PENDING |
| `GLB-PRIV-001` | User, Steering 6.4 | Treat utterances as sensitive residential data. | P12-P15 | Persistence/log scan | Privacy evidence | PENDING |
| `GLB-PRIV-002` | User, Steering 6.4 | Treat catalog names and locations as sensitive residential data. | P10-P15 | Persistence/log scan | Privacy evidence | PENDING |
| `GLB-PRIV-003` | ADR-0007 | Treat session state as sensitive residential data. | P12-P15 | Sensitive-type and sink-policy audit | Privacy evidence | PENDING |
| `GLB-PRIV-004` | ADR-0007 | Prevent residential data from being exported as telemetry. | P13-P15 | Telemetry dependency scan and network-denied canary test | Privacy evidence | PENDING |
| `GLB-PRIV-005` | ADR-0007 | Treat Home Assistant entity identifiers as sensitive residential data. | P10-P15 | Sensitive-type and sink-policy audit | Privacy evidence | PENDING |
| `GLB-PRIV-006` | ADR-0007 | Treat Home Assistant aliases as sensitive residential data. | P10-P15 | Sensitive-type and sink-policy audit | Privacy evidence | PENDING |
| `GLB-PRIV-007` | ADR-0007 | Treat Home Assistant device identifiers as sensitive residential data. | P10-P15 | Sensitive-type and sink-policy audit | Privacy evidence | PENDING |
| `GLB-PRIV-008` | ADR-0007 | Treat Home Assistant catalog snapshots as sensitive residential data. | P10-P15 | Sensitive-type and sink-policy audit | Privacy evidence | PENDING |
| `GLB-PRIV-009` | User | Prohibit credentials, residential dumps or Home Assistant state, and user utterances from every Git object reachable from any project ref throughout all phases. | All | Per-phase all-ref reachable-object sentinel matrix and scanner tests for every prohibited content class | Phase evidence | PENDING |
| `GLB-PERSIST-001` | ADR-0007 | Require owner-only permissions for any opt-in residential-data persistence. | P15, FINAL | Ownership and mode tests | Privacy evidence | PENDING |
| `GLB-PERSIST-002` | ADR-0007 | Require bounded retention for any opt-in residential-data persistence. | P15, FINAL | Logical-time retention test | Privacy evidence | PENDING |
| `GLB-PERSIST-003` | ADR-0007 | Require explicit deletion for any opt-in residential-data persistence. | P15, FINAL | Deletion lifecycle test | Privacy evidence | PENDING |
| `GLB-PERSIST-004` | ADR-0007 | Disclose backup inclusion for any opt-in residential-data persistence. | P15, FINAL | Backup-manifest audit | Privacy evidence | PENDING |
| `GLB-PERSIST-005` | ADR-0007 | Require an accepted privacy ADR before enabling residential-data persistence. | P15, FINAL | ADR status and feature-gate test | Privacy evidence | PENDING |
| `GLB-ENG-001` | Steering 6.4 | Give every new behavior a test. | All | Requirement-to-test review | Phase evidence | PENDING |
| `GLB-ENG-002` | Steering 6.4 | Give every bug fix a regression test. | All | Finding-to-test review | Phase evidence | PENDING |
| `GLB-DEPS-001` | Steering 6.4 | Pin every build and runtime dependency. | P01-P15 | Lockfile/SBOM audit | P15 evidence | PENDING |
| `GLB-DEPS-002` | Steering 6.4 | Record license and purpose for every dependency. | P01-P15 | License inventory audit | P15 evidence | PENDING |
| `GLB-DEPS-003` | Steering 6.4 | Perform a supply-chain review for every new dependency. | P01-P15 | Dependency admission report | Phase evidence | PENDING |
| `GLB-DEPS-004` | ADR-0001 | Record an identifiable owner for every external dependency. | P01-P15 | Dependency-owner field and deletion tests | Phase dependency evidence | PENDING |
| `GLB-DEPS-005` | ADR-0001 | Record an immutable source version for every external dependency. | P01-P15 | Version and source-identity substitution tests | Phase dependency evidence | PENDING |
| `GLB-DEPS-006` | ADR-0001 | Retain the complete license text for every external dependency. | P01-P15 | License-text hash and completeness audit | Phase dependency evidence | PENDING |
| `GLB-DEPS-007` | ADR-0001 | Record byte-level provenance for every external dependency. | P01-P15 | Archive hash and provenance-chain audit | Phase dependency evidence | PENDING |
| `GLB-LIC-001` | ADR-0001 | Admit attribution or share-alike material only after compatibility is proven. | P01-P15 | Incompatible-license admission negatives | Phase admission evidence | PENDING |
| `GLB-LIC-002` | ADR-0001 | Isolate attribution or share-alike material from incompatibly licensed paths. | P01-P15 | Dependency/path contamination test | Phase admission evidence | PENDING |
| `GLB-LIC-003` | ADR-0001 | Record every attribution or share-alike obligation for each admitted non-data input. | P01-P15 | Obligation-field deletion mutations | Phase license inventories | PENDING |
| `GLB-LIC-004` | ADR-0001 | Reject source-policy weakening without newer explicit user direction recorded in an accepted ADR amendment or superseding ADR. | All | Policy-delta and chronology mutations | Decision evidence | PENDING |
| `GLB-TOOL-001` | ADR-0001 | Apply the complete P00 tool provenance and rights schema to every intentionally invoked validation, build, test, packaging, and runtime executable. | P01-P15 | Invocation inventory and per-field deletion tests | Phase toolchain evidence | PENDING |
| `GLB-EVID-001` | Steering 6.4 | Back every pass claim with an executed command and retained result. | All | Evidence review | Phase evidence | PENDING |
| `GLB-GIT-001` | Steering 6.4 | Keep every project change recoverable through Git. | All | Git ancestry and worktree audit | Phase evidence | PENDING |
| `GLB-GIT-002` | Steering 6.4 | Keep each phase checkpoint commit atomic. | All | Commit change-scope audit | Phase evidence | PENDING |
| `GLB-SCAFF-001` | Steering 7 | Create no empty crate or placeholder module without its first contract, consumer, and tests. | P01-P15 | Workspace and call-graph audit | Phase evidence | PENDING |

## Quality and performance requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `NFR-ACC-002` | User | Achieve a two-sided 95% Wilson lower bound of at least 98.4% exact semantic success. | P15 | Versioned held-out runner | P15 evidence | PENDING |
| `NFR-ACC-003` | ADR-0005 | Count in-domain abstention as exact-semantic failure. | P15 | Metric oracle test | P15 evidence | PENDING |
| `NFR-ACC-005` | ADR-0005 | Freeze held-out source coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-006` | ADR-0005 | Freeze held-out utterance-family coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-007` | ADR-0005 | Freeze held-out intent coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-008` | ADR-0005 | Freeze held-out Home Assistant domain coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-009` | ADR-0005 | Freeze held-out slot-kind coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-010` | ADR-0005 | Freeze held-out graph-shape coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-011` | ADR-0005 | Freeze held-out outcome coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-012` | ADR-0005 | Freeze held-out ambiguity-class coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-013` | ADR-0005 | Freeze held-out noise-stratum coverage before implementation tuning. | P02 | Coverage manifest and freeze evidence | P02 evidence | SATISFIED |
| `NFR-ACC-016` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported source stratum. | P15 | Source-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-017` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported utterance-family stratum. | P15 | Family-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-018` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported intent stratum. | P15 | Intent-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-019` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported Home Assistant domain stratum. | P15 | Domain-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-020` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported slot-kind stratum. | P15 | Slot-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-021` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported graph-shape stratum. | P15 | Graph-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-022` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported outcome stratum. | P15 | Outcome-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-023` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported ambiguity stratum. | P15 | Ambiguity-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-024` | ADR-0005 | Require a two-sided 95% Wilson lower bound of at least 98.4% for every declared supported noise stratum. | P15 | Noise-stratum release-gate test | P15 evidence | PENDING |
| `NFR-ACC-026` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across source strata. | P15 | Source macro release gate | P15 evidence | PENDING |
| `NFR-ACC-027` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across utterance-family strata. | P15 | Family macro release gate | P15 evidence | PENDING |
| `NFR-ACC-028` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across intent strata. | P15 | Intent macro release gate | P15 evidence | PENDING |
| `NFR-ACC-029` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across Home Assistant domain strata. | P15 | Domain macro release gate | P15 evidence | PENDING |
| `NFR-ACC-030` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across slot-kind strata. | P15 | Slot macro release gate | P15 evidence | PENDING |
| `NFR-ACC-031` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across graph-shape strata. | P15 | Graph macro release gate | P15 evidence | PENDING |
| `NFR-ACC-032` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across outcome strata. | P15 | Outcome macro release gate | P15 evidence | PENDING |
| `NFR-ACC-033` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across ambiguity strata. | P15 | Ambiguity macro release gate | P15 evidence | PENDING |
| `NFR-ACC-034` | ADR-0005 | Require at least 98.4% unweighted macro exact-semantic accuracy across noise strata. | P15 | Noise macro release gate | P15 evidence | PENDING |
| `NFR-ACC-036` | ADR-0005 | Record target cardinality for every held-out scored case. | P02 | Coverage-manifest schema test | P02 evidence | SATISFIED |
| `NFR-FP-001` | Steering, ADR-0005 | Produce zero false plans on safety-sensitive suites. | P15, P16 | Frozen safety-suite manifest and runner | P16 evidence | PENDING |
| `NFR-PERF-001` | ADR-0005 | Freeze source performance strata before implementation tuning. | P02 | Performance-manifest source-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-002` | ADR-0005 | Freeze utterance-family performance strata before implementation tuning. | P02 | Performance-manifest family-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-003` | ADR-0005 | Freeze intent performance strata before implementation tuning. | P02 | Performance-manifest intent-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-004` | ADR-0005 | Freeze Home Assistant domain performance strata before implementation tuning. | P02 | Performance-manifest domain-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-005` | ADR-0005 | Freeze slot-kind performance strata before implementation tuning. | P02 | Performance-manifest slot-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-006` | ADR-0005 | Freeze graph-shape performance strata before implementation tuning. | P02 | Performance-manifest graph-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-007` | ADR-0005 | Freeze outcome performance strata before implementation tuning. | P02 | Performance-manifest outcome-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-008` | ADR-0005 | Freeze ambiguity performance strata before implementation tuning. | P02 | Performance-manifest ambiguity-axis check | P02 evidence | SATISFIED |
| `NFR-PERF-009` | ADR-0005 | Freeze noise performance strata before implementation tuning. | P02 | Performance-manifest noise-axis check | P02 evidence | SATISFIED |
| `NFR-CORE-001` | User | Reach median 20,000 words/s across five core runs. | P15 | Single-thread benchmark | P15 evidence | PENDING |
| `NFR-CORE-003` | ADR-0005 | Reach median 20,000 words/s across five core runs in every source stratum. | P15 | Source-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-004` | ADR-0005 | Reach median 20,000 words/s across five core runs in every utterance-family stratum. | P15 | Family-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-005` | ADR-0005 | Reach median 20,000 words/s across five core runs in every intent stratum. | P15 | Intent-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-006` | ADR-0005 | Reach median 20,000 words/s across five core runs in every Home Assistant domain stratum. | P15 | Domain-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-007` | ADR-0005 | Reach median 20,000 words/s across five core runs in every slot-kind stratum. | P15 | Slot-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-008` | ADR-0005 | Reach median 20,000 words/s across five core runs in every graph-shape stratum. | P15 | Graph-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-009` | ADR-0005 | Reach median 20,000 words/s across five core runs in every outcome stratum. | P15 | Outcome-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-010` | ADR-0005 | Reach median 20,000 words/s across five core runs in every ambiguity stratum. | P15 | Ambiguity-stratum core benchmark | P15 evidence | PENDING |
| `NFR-CORE-011` | ADR-0005 | Reach median 20,000 words/s across five core runs in every noise stratum. | P15 | Noise-stratum core benchmark | P15 evidence | PENDING |
| `NFR-E2E-001` | User | Reach median 400 utterances/s across five warm end-to-end runs. | P15 | Mocked integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-003` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every source stratum. | P15 | Source-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-004` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every utterance-family stratum. | P15 | Family-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-005` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every intent stratum. | P15 | Intent-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-006` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every Home Assistant domain stratum. | P15 | Domain-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-007` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every slot-kind stratum. | P15 | Slot-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-008` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every graph-shape stratum. | P15 | Graph-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-009` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every outcome stratum. | P15 | Outcome-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-010` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every ambiguity stratum. | P15 | Ambiguity-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-E2E-011` | ADR-0005 | Reach median 400 utterances/s across five warm end-to-end runs in every noise stratum. | P15 | Noise-stratum integration benchmark | P15 evidence | PENDING |
| `NFR-LAT-001` | Steering P15, ADR-0005 | Report p50 latency. | P15 | Raw benchmark aggregation | P15 evidence | PENDING |
| `NFR-RSS-001` | Steering P15 | Report peak resident memory. | P15 | Process memory measurement | P15 evidence | PENDING |
| `NFR-START-001` | Steering P15 | Report startup time separately. | P15 | Cold-start benchmark | P15 evidence | PENDING |
| `NFR-SIZE-001` | Steering P15 | Report executable binary size. | P15 | Artifact byte count | P15 evidence | PENDING |
| `NFR-SIZE-002` | Steering P15 | Report compiled runtime data size separately from executable size. | P15 | Artifact byte count | P15 evidence | PENDING |
| `NFR-SIZE-003` | Steering P15 | Report distributable package size separately from executable and data sizes. | P15 | Artifact byte count | P15 evidence | PENDING |
| `NFR-HW-001` | ADR-0005 | Report the CPU model. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-WORD-001` | ADR-0005 | Freeze an independent Unicode word-count algorithm before benchmarking. | P04, P15 | Versioned counter tests | P15 evidence | SATISFIED |
| `NFR-WARM-001` | ADR-0005 | Run three untimed warmup passes before every five-run performance measurement. | P15 | Benchmark-runner sequence test | P15 evidence | PENDING |
| `NFR-BENCH-001` | ADR-0005 | Do not claim direct product equivalence from the adopted numerical targets. | P15, FINAL | Benchmark-claim audit | P15 and release evidence | PENDING |
| `NFR-ACC-037` | ADR-0005 | Use only Apache-2.0, provenance-bound, project-authored synthetic cases in the scored conformance evaluation. | P02, P15 | Case-provenance and license audit | P02 and P15 evidence | PENDING |
| `NFR-ACC-038` | ADR-0005 | Use a held-out evaluation for the global accuracy gate. | P02, P15 | Split and runner audit | P02 and P15 evidence | PENDING |
| `NFR-ACC-039` | ADR-0005 | Limit the scored evaluation language to PT-BR. | P02 | Dataset-language audit | P02 evidence | SATISFIED |
| `NFR-ACC-040` | ADR-0005 | Evaluate Home Assistant semantic behavior. | P02, P15 | Coverage-manifest audit | P15 evidence | PENDING |
| `NFR-FP-002` | ADR-0005 | Produce zero false plans on contradiction suites. | P15, P16 | Frozen contradiction-suite manifest and runner | P16 evidence | PENDING |
| `NFR-FP-003` | ADR-0005 | Produce zero false plans on ambiguity suites. | P15, P16 | Frozen ambiguity-suite manifest and runner | P16 evidence | PENDING |
| `NFR-FP-004` | ADR-0005 | Produce zero false plans on stale-state suites. | P15, P16 | Frozen stale-state-suite manifest and runner | P16 evidence | PENDING |
| `NFR-FP-005` | ADR-0005 | Produce zero false plans on explicit negative suites. | P15, P16 | Frozen negative-suite manifest and runner | P16 evidence | PENDING |
| `NFR-FP-006` | ADR-0005 | Evaluate every zero-false-plan gate separately from accuracy gates. | P15, P16 | Gate-independence test | P16 evidence | PENDING |
| `NFR-FP-007` | ADR-0005 | Do not average a false-plan gate into another metric. | P15, P16 | Aggregation negative test | P16 evidence | PENDING |
| `NFR-FP-008` | ADR-0005 | Freeze safety-sensitive, contradiction, ambiguity, stale-state, and explicit-negative suite identities and oracles before implementation tuning. | P02 | Freeze chronology and manifest audit | P02 evidence | SATISFIED |
| `NFR-FP-009` | ADR-0005 | Require every zero-false-plan suite and every frozen coverage class to contain at least one distinct Apache-2.0 provenance-bound case. | P02 | Nonzero cardinality, distinctness, provenance, and license checks | P02 evidence | SATISFIED |
| `NFR-FP-010` | ADR-0005 | Cover every frozen release risk and confirmation class in the safety-sensitive suite. | P02 | Risk-model-to-suite coverage audit | P02 evidence | SATISFIED |
| `NFR-FP-011` | ADR-0005 | Cover every frozen graph-contradiction class in the contradiction suite. | P02 | Contradiction-model-to-suite coverage audit | P02 evidence | SATISFIED |
| `NFR-FP-012` | ADR-0005 | Cover every frozen supported ambiguity class in the ambiguity suite. | P02 | Ambiguity-model-to-suite coverage audit | P02 evidence | SATISFIED |
| `NFR-FP-013` | ADR-0005 | Cover every frozen stale-state acceptance boundary in the stale-state suite. | P02 | Stale-boundary-to-suite coverage audit | P02 evidence | SATISFIED |
| `NFR-FP-014` | ADR-0005 | Cover every frozen unsupported, out-of-domain, and denied semantic family in the explicit-negative suite. | P02 | Negative-taxonomy-to-suite coverage audit | P02 evidence | SATISFIED |
| `NFR-FP-015` | ADR-0005 | Record immutable suite ID, case ID, generator record identity, canonical semantic identity, expected non-plan outcome, coverage class, provenance, and license for every zero-false-plan case. | P02 | Suite-manifest schema and provenance audit | P02 evidence | SATISFIED |
| `NFR-FP-016` | ADR-0005 | Prevent one canonical semantic identity from satisfying two coverage classes in the same zero-false-plan suite. | P02 | Duplicate-class identity rejection test | P02 evidence | SATISFIED |
| `NFR-FP-017` | ADR-0005 | Invalidate an affected zero-false-plan suite and its results after any post-freeze identity, oracle, taxonomy, or quota change. | P02-P16 | Mutation and refreeze chronology tests | P16 evidence | PENDING |
| `NFR-FP-018` | ADR-0005 | Report exact suite and per-class cardinality, coverage, and false-plan counts for every zero-false-plan gate. | P15, P16 | Report schema and source-manifest reconciliation | P16 evidence | PENDING |
| `NFR-MEAS-001` | ADR-0005 | Measure the complete core pipeline for core throughput. | P15 | Benchmark-boundary audit | P15 evidence | PENDING |
| `NFR-MEAS-002` | ADR-0005 | Measure core throughput with one execution thread. | P15 | Thread-count assertion | P15 evidence | PENDING |
| `NFR-MEAS-003` | ADR-0005 | Keep the measured core pipeline in memory. | P15 | I/O and boundary instrumentation | P15 evidence | PENDING |
| `NFR-MEAS-004` | ADR-0005 | Run gated benchmarks on documented reference hardware. | P15 | Benchmark-host manifest check | P15 evidence | PENDING |
| `NFR-MEAS-005` | ADR-0005 | Measure the warm end-to-end NLU path. | P15 | Benchmark-boundary audit | P15 evidence | PENDING |
| `NFR-MEAS-006` | ADR-0005 | Use an in-process Home Assistant mock for the end-to-end benchmark. | P15 | Process-boundary assertion | P15 evidence | PENDING |
| `NFR-E2E-012` | ADR-0005 | Make the in-process Home Assistant benchmark mock deterministic. | P15 | Repeatability test | P15 evidence | PENDING |
| `NFR-HOLD-001` | ADR-0005 | Isolate the held-out set before implementation tuning. | P02 | Split chronology audit | P02 evidence | SATISFIED |
| `NFR-HOLD-002` | ADR-0005 | Split held-out cases by source. | P02 | Source-group split test | P02 evidence | SATISFIED |
| `NFR-HOLD-003` | ADR-0005 | Split held-out cases by utterance family. | P02 | Family-group split test | P02 evidence | SATISFIED |
| `NFR-HOLD-004` | ADR-0005 | Exclude Sophia-derived language from the held-out set. | P02 | Provenance rejection audit | P02 evidence | SATISFIED |
| `NFR-HOLD-005` | ADR-0005 | Limit AI-origin language in the held-out set to the exact `PROJECT_AUTHORED_SYNTHETIC` corpus authorized by `USR-016`. | P02 | Origin, authorization, and provenance audit | P02 evidence | SATISFIED |
| `NFR-CASE-001` | ADR-0005 | Freeze a scored-case identity manifest. | P02 | Immutable manifest check | P02 evidence | SATISFIED |
| `NFR-CASE-002` | ADR-0005 | Freeze a scored-case coverage manifest. | P02 | Immutable manifest check | P02 evidence | SATISFIED |
| `NFR-CASE-003` | ADR-0005 | Freeze scored-case identities before implementation sees results. | P02 | Chronology and access audit | P02 evidence | SATISFIED |
| `NFR-CASE-004` | ADR-0005 | Freeze scored-case coverage before implementation sees results. | P02 | Chronology and access audit | P02 evidence | SATISFIED |
| `NFR-CASE-005` | ADR-0005 | Give every scored case a unique generator record identity. | P02 | Generator-identity uniqueness test | P02 evidence | SATISFIED |
| `NFR-CASE-006` | ADR-0005 | Give every scored case a unique canonical semantic case identity. | P02 | Semantic-identity uniqueness test | P02 evidence | SATISFIED |
| `NFR-CASE-007` | ADR-0005 | Record source for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-008` | ADR-0005 | Record utterance family for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-009` | ADR-0005 | Record intent for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-010` | ADR-0005 | Record Home Assistant domain for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-011` | ADR-0005 | Record slot kinds for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-012` | ADR-0005 | Record graph shape for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-013` | ADR-0005 | Record expected outcome for every scored case. | P02 | Manifest schema and oracle test | P02 evidence | SATISFIED |
| `NFR-CASE-014` | ADR-0005 | Record ambiguity class for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-CASE-020` | ADR-0005 | Record the pre-engine generator specification and review lineage for every expected outcome. | P02 | Generator-oracle and review-lineage schema test | P02 evidence | SATISFIED |
| `NFR-CASE-021` | ADR-0005 | Reject every case whose expected outcome was established, corrected, or validated by project NLU output. | P02 | Self-output oracle rejection tests | P02 evidence | SATISFIED |
| `NFR-CASE-015` | ADR-0005 | Record noise stratum for every scored case. | P02 | Manifest schema test | P02 evidence | SATISFIED |
| `NFR-COV-001` | ADR-0005 | Cover every declared supported intent. | P02 | Coverage-denominator test | P02 evidence | SATISFIED |
| `NFR-COV-002` | ADR-0005 | Cover every declared supported Home Assistant domain. | P02 | Coverage-denominator test | P02 evidence | SATISFIED |
| `NFR-COV-003` | ADR-0005 | Cover every typed slot class used by the release. | P02 | Slot-coverage test | P02 evidence | SATISFIED |
| `NFR-COV-004` | ADR-0005 | Cover every entity class used by the release. | P02 | Entity-coverage test | P02 evidence | SATISFIED |
| `NFR-COV-005` | ADR-0005 | Cover every clarification class used by the release. | P02 | Clarification-coverage test | P02 evidence | SATISFIED |
| `NFR-COV-006` | ADR-0005 | Cover every abstention class used by the release. | P02 | Abstention-coverage test | P02 evidence | SATISFIED |
| `NFR-COV-007` | ADR-0005 | Cover every negative class used by the release. | P02 | Negative-coverage test | P02 evidence | SATISFIED |
| `NFR-COV-008` | ADR-0005 | Cover every graph class used by the release. | P02 | Graph-coverage test | P02 evidence | SATISFIED |
| `NFR-CASE-016` | ADR-0005 | Freeze evaluation quotas with the held-out split. | P02 | Frozen-quota digest check | P02 evidence | SATISFIED |
| `NFR-CASE-017` | ADR-0005 | Freeze evaluation weighting with the held-out split. | P02 | Frozen-weight digest check | P02 evidence | SATISFIED |
| `NFR-CASE-018` | ADR-0005 | Do not change evaluation quotas in response to model results. | P02, P15 | Chronology and digest audit | P15 evidence | PENDING |
| `NFR-CASE-019` | ADR-0005 | Do not change evaluation weighting in response to model results. | P02, P15 | Chronology and digest audit | P15 evidence | PENDING |
| `NFR-AREP-001` | ADR-0005 | Report the scored sample count. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-AREP-002` | ADR-0005 | Report the two-sided 95% Wilson interval. | P15 | Independent interval recomputation | P15 evidence | PENDING |
| `NFR-AREP-003` | ADR-0005 | Report the exact-semantic point estimate. | P15 | Independent metric recomputation | P15 evidence | PENDING |
| `NFR-AREP-004` | ADR-0005 | Report unweighted macro results across sources. | P15 | Source macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-005` | ADR-0005 | Report unweighted macro results across utterance families. | P15 | Family macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-006` | ADR-0005 | Report unweighted macro results across intents. | P15 | Intent macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-007` | ADR-0005 | Report unweighted macro results across domains. | P15 | Domain macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-008` | ADR-0005 | Report unweighted macro results across slot kinds. | P15 | Slot macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-009` | ADR-0005 | Report unweighted macro results across graph shapes. | P15 | Graph macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-010` | ADR-0005 | Report unweighted macro results across outcomes. | P15 | Outcome macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-011` | ADR-0005 | Report unweighted macro results across ambiguity classes. | P15 | Ambiguity macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-012` | ADR-0005 | Report unweighted macro results across noise strata. | P15 | Noise macro recomputation | P15 evidence | PENDING |
| `NFR-AREP-013` | ADR-0005 | Report results for every frozen source stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-014` | ADR-0005 | Report results for every frozen family stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-015` | ADR-0005 | Report results for every frozen intent stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-016` | ADR-0005 | Report results for every frozen domain stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-017` | ADR-0005 | Report results for every frozen slot stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-018` | ADR-0005 | Report results for every frozen graph stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-019` | ADR-0005 | Report results for every frozen outcome stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-020` | ADR-0005 | Report results for every frozen ambiguity stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-AREP-021` | ADR-0005 | Report results for every frozen noise stratum. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-ACC-041` | ADR-0005 | Define and validate the scored dataset before freezing it. | P02 | Dataset-validity gate | P02 evidence | SATISFIED |
| `NFR-ACC-042` | ADR-0005 | Freeze at least 3,715 distinct scored cases. | P02 | Identity and count audit | P02 evidence | SATISFIED |
| `NFR-ACC-043` | ADR-0005 | Freeze the minimum scored set before implementation tuning. | P02 | Freeze chronology audit | P02 evidence | SATISFIED |
| `NFR-ACC-044` | ADR-0005 | Do not lower the 3,715-case minimum through alternate sample-size justification. | P02, P15 | Minimum mutation test | P15 evidence | PENDING |
| `NFR-ACC-045` | ADR-0005 | Do not let a duplicate increase the scored count. | P02, P15 | Duplicate-injection test | P15 evidence | PENDING |
| `NFR-ACC-046` | ADR-0005 | Require 237 distinct scored cases in every supported source stratum. | P02, P15 | Source quota audit | P15 evidence | PENDING |
| `NFR-ACC-047` | ADR-0005 | Require 237 distinct scored cases in every supported family stratum. | P02, P15 | Family quota audit | P15 evidence | PENDING |
| `NFR-ACC-048` | ADR-0005 | Require 237 distinct scored cases in every supported intent stratum. | P02, P15 | Intent quota audit | P15 evidence | PENDING |
| `NFR-ACC-049` | ADR-0005 | Require 237 distinct scored cases in every supported domain stratum. | P02, P15 | Domain quota audit | P15 evidence | PENDING |
| `NFR-ACC-050` | ADR-0005 | Require 237 distinct scored cases in every supported slot stratum. | P02, P15 | Slot quota audit | P15 evidence | PENDING |
| `NFR-ACC-051` | ADR-0005 | Require 237 distinct scored cases in every supported graph stratum. | P02, P15 | Graph quota audit | P15 evidence | PENDING |
| `NFR-ACC-052` | ADR-0005 | Require 237 distinct scored cases in every supported outcome stratum. | P02, P15 | Outcome quota audit | P15 evidence | PENDING |
| `NFR-ACC-053` | ADR-0005 | Require 237 distinct scored cases in every supported ambiguity stratum. | P02, P15 | Ambiguity quota audit | P15 evidence | PENDING |
| `NFR-ACC-054` | ADR-0005 | Require 237 distinct scored cases in every supported noise stratum. | P02, P15 | Noise quota audit | P15 evidence | PENDING |
| `NFR-ACC-055` | ADR-0005 | Do not lower the 237-case floor even for a zero-failure stratum. | P02, P15 | Floor mutation test | P15 evidence | PENDING |
| `NFR-ACC-056` | ADR-0005 | Do not treat passage of the global Wilson gate as sufficient for release. | P15 | Global-only negative fixture | P15 evidence | PENDING |
| `NFR-ACC-057` | ADR-0005 | Require pre-implementation frozen quota evidence for each supported stratum. | P02, P15 | Quota-evidence and freeze-chronology audit | P15 evidence | PENDING |
| `NFR-ACC-058` | ADR-0005 | Require coverage evidence for each supported stratum. | P02, P15 | Coverage-evidence audit | P15 evidence | PENDING |
| `NFR-ACC-059` | ADR-0005 | Report a stratum with missing frozen quota evidence as insufficiently evaluated. | P15 | Missing-quota report test | P15 evidence | PENDING |
| `NFR-ACC-060` | ADR-0005 | Report a stratum with missing coverage evidence as insufficiently evaluated. | P15 | Missing-coverage report test | P15 evidence | PENDING |
| `NFR-ACC-061` | ADR-0005 | Do not declare a stratum supported without frozen quota evidence. | P15 | Support-claim negative test | P15 evidence | PENDING |
| `NFR-ACC-062` | ADR-0005 | Do not declare a stratum supported without coverage evidence. | P15 | Support-claim negative test | P15 evidence | PENDING |
| `NFR-PCORP-001` | ADR-0005 | Use a performance corpus separate from the accuracy evaluation. | P02, P15 | Corpus-identity audit | P15 evidence | PENDING |
| `NFR-PCORP-002` | ADR-0005 | Freeze the representative performance corpus before tuning. | P02 | Corpus digest and chronology | P02 evidence | SATISFIED |
| `NFR-PCORP-003` | ADR-0005 | Make the performance corpus representative of frozen coverage. | P02 | Coverage comparison | P02 evidence | SATISFIED |
| `NFR-PCORP-004` | ADR-0005 | Derive the performance corpus from the held-out coverage manifest. | P02 | Derivation-ledger audit | P02 evidence | SATISFIED |
| `NFR-HOLD-006` | ADR-0005 | Do not expose held-out text while deriving the performance corpus. | P02 | Access-boundary audit | P02 evidence | SATISFIED |
| `NFR-PCORP-005` | ADR-0005 | Give every performance item a frozen exact-semantic outcome. | P02 | Performance-manifest schema test | P02 evidence | SATISFIED |
| `NFR-PCORP-006` | ADR-0005 | Make a run ineligible when untimed semantic preflight fails. | P15 | Preflight-failure test | P15 evidence | PENDING |
| `NFR-PCORP-007` | ADR-0005 | Count timed words only when the outcome matches its oracle. | P15 | Wrong-outcome counter test | P15 evidence | PENDING |
| `NFR-PCORP-008` | ADR-0005 | Count timed utterances only when the outcome matches its oracle. | P15 | Wrong-outcome counter test | P15 evidence | PENDING |
| `NFR-PCORP-009` | ADR-0005 | Exclude abstention from throughput unless it is the frozen expected outcome. | P15 | Abstention counter test | P15 evidence | PENDING |
| `NFR-PCORP-010` | ADR-0005 | Exclude errors from throughput unless the error is the frozen expected outcome. | P15 | Error counter test | P15 evidence | PENDING |
| `NFR-PCORP-011` | ADR-0005 | Exclude partial output from throughput unless it is the frozen expected outcome. | P15 | Partial-output counter test | P15 evidence | PENDING |
| `NFR-PCORP-012` | ADR-0005 | Repeat only the complete corpus when extending a timed run. | P15 | Runner cycle test | P15 evidence | PENDING |
| `NFR-PCORP-013` | ADR-0005 | Repeat the corpus in canonical order. | P15 | Stable-order test | P15 evidence | PENDING |
| `NFR-PCORP-014` | ADR-0005 | Use corpus repetition only to reach a one-second run. | P15 | Duration-policy test | P15 evidence | PENDING |
| `NFR-PCORP-015` | ADR-0005 | Do not replace corpus cycles with repetition of an easy item. | P15 | Easy-item mutation test | P15 evidence | PENDING |
| `NFR-PCORP-016` | ADR-0005 | Do not omit a performance stratum from a run. | P15 | Stratum-completeness test | P15 evidence | PENDING |
| `NFR-PERF-013` | ADR-0005 | Require 237 distinct items in every source performance stratum. | P02 | Source quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-014` | ADR-0005 | Require 237 distinct items in every family performance stratum. | P02 | Family quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-015` | ADR-0005 | Require 237 distinct items in every intent performance stratum. | P02 | Intent quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-016` | ADR-0005 | Require 237 distinct items in every domain performance stratum. | P02 | Domain quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-017` | ADR-0005 | Require 237 distinct items in every slot performance stratum. | P02 | Slot quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-018` | ADR-0005 | Require 237 distinct items in every graph performance stratum. | P02 | Graph quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-019` | ADR-0005 | Require 237 distinct items in every outcome performance stratum. | P02 | Outcome quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-020` | ADR-0005 | Require 237 distinct items in every ambiguity performance stratum. | P02 | Ambiguity quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-021` | ADR-0005 | Require 237 distinct items in every noise performance stratum. | P02 | Noise quota audit | P02 evidence | SATISFIED |
| `NFR-PERF-022` | ADR-0005 | Do not let duplicates satisfy a source performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-023` | ADR-0005 | Do not let duplicates satisfy a family performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-024` | ADR-0005 | Do not let duplicates satisfy an intent performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-025` | ADR-0005 | Do not let duplicates satisfy a domain performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-026` | ADR-0005 | Do not let duplicates satisfy a slot performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-027` | ADR-0005 | Do not let duplicates satisfy a graph performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-028` | ADR-0005 | Do not let duplicates satisfy an outcome performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-029` | ADR-0005 | Do not let duplicates satisfy an ambiguity performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-030` | ADR-0005 | Do not let duplicates satisfy a noise performance quota. | P02 | Duplicate-injection test | P02 evidence | SATISFIED |
| `NFR-PERF-031` | ADR-0005 | Require the complete performance corpus to pass untimed semantic preflight. | P15 | Corpus preflight audit | P15 evidence | PENDING |
| `NFR-PERF-032` | ADR-0005 | Require every source performance stratum to pass untimed semantic preflight. | P15 | Source preflight audit | P15 evidence | PENDING |
| `NFR-PERF-033` | ADR-0005 | Require every family performance stratum to pass untimed semantic preflight. | P15 | Family preflight audit | P15 evidence | PENDING |
| `NFR-PERF-034` | ADR-0005 | Require every intent performance stratum to pass untimed semantic preflight. | P15 | Intent preflight audit | P15 evidence | PENDING |
| `NFR-PERF-035` | ADR-0005 | Require every domain performance stratum to pass untimed semantic preflight. | P15 | Domain preflight audit | P15 evidence | PENDING |
| `NFR-PERF-036` | ADR-0005 | Require every slot performance stratum to pass untimed semantic preflight. | P15 | Slot preflight audit | P15 evidence | PENDING |
| `NFR-PERF-037` | ADR-0005 | Require every graph performance stratum to pass untimed semantic preflight. | P15 | Graph preflight audit | P15 evidence | PENDING |
| `NFR-PERF-038` | ADR-0005 | Require every outcome performance stratum to pass untimed semantic preflight. | P15 | Outcome preflight audit | P15 evidence | PENDING |
| `NFR-PERF-039` | ADR-0005 | Require every ambiguity performance stratum to pass untimed semantic preflight. | P15 | Ambiguity preflight audit | P15 evidence | PENDING |
| `NFR-PERF-040` | ADR-0005 | Require every noise performance stratum to pass untimed semantic preflight. | P15 | Noise preflight audit | P15 evidence | PENDING |
| `NFR-PCORP-017` | ADR-0005 | Assign each item to at most one source stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-018` | ADR-0005 | Assign each item to at most one family stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-019` | ADR-0005 | Assign each item to at most one intent stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-020` | ADR-0005 | Assign each item to at most one domain stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-021` | ADR-0005 | Assign each item to at most one slot stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-022` | ADR-0005 | Assign each item to at most one graph stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-023` | ADR-0005 | Assign each item to at most one outcome stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-024` | ADR-0005 | Assign each item to at most one ambiguity stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-025` | ADR-0005 | Assign each item to at most one noise stratum. | P02 | Membership-cardinality test | P02 evidence | SATISFIED |
| `NFR-PCORP-027` | ADR-0005 | Freeze all performance item identities before implementation tuning. | P02 | Identity digest and chronology | P02 evidence | SATISFIED |
| `NFR-PCORP-028` | ADR-0005 | Freeze all performance quotas before implementation tuning. | P02 | Quota digest and chronology | P02 evidence | SATISFIED |
| `NFR-TPUT-001` | ADR-0005 | Evaluate complete-corpus and per-stratum throughput gates independently. | P15 | Gate-independence test | P15 evidence | PENDING |
| `NFR-TPUT-002` | ADR-0005 | Do not let a fast performance stratum compensate for a slow stratum. | P15 | Weighted-average negative test | P15 evidence | PENDING |
| `NFR-HW-002` | ADR-0005 | Report the CPU architecture. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-HW-003` | ADR-0005 | Report the benchmark core allocation. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-HW-004` | ADR-0005 | Report the operating system. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-HW-005` | ADR-0005 | Report the compiler identity and version. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-HW-006` | ADR-0005 | Report the build profile. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-BENCH-002` | ADR-0005 | Report the measured package version. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-BENCH-003` | ADR-0005 | Report the measured data version. | P15 | Report schema test | P15 evidence | PENDING |
| `NFR-BENCH-004` | ADR-0005 | Report the performance-corpus identity. | P15 | Corpus-digest comparison | P15 evidence | PENDING |
| `NFR-WARM-002` | ADR-0005 | Include all three warmup runs in the performance report. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-RUN-001` | ADR-0005 | Include all five measured runs in the performance report. | P15 | Report completeness test | P15 evidence | PENDING |
| `NFR-LAT-002` | ADR-0005 | Report p95 latency. | P15 | Raw-run recomputation | P15 evidence | PENDING |
| `NFR-LAT-003` | ADR-0005 | Report p99 latency. | P15 | Raw-run recomputation | P15 evidence | PENDING |
| `NFR-TPUT-003` | ADR-0005 | Report measured throughput. | P15 | Raw-run recomputation | P15 evidence | PENDING |
| `NFR-CORE-012` | ADR-0005 | Exclude startup from core timing. | P15 | Timing-boundary instrumentation | P15 evidence | PENDING |
| `NFR-CORE-013` | ADR-0005 | Exclude configuration loading from core timing. | P15 | Timing-boundary instrumentation | P15 evidence | PENDING |
| `NFR-CORE-014` | ADR-0005 | Exclude I/O from core timing. | P15 | I/O-denied benchmark test | P15 evidence | PENDING |
| `NFR-CORE-015` | ADR-0005 | Exclude the Home Assistant adapter from core timing. | P15 | Dependency and timing-boundary audit | P15 evidence | PENDING |
| `NFR-MEAS-007` | ADR-0005 | State every boundary included in end-to-end timing. | P15 | Boundary-manifest completeness test | P15 evidence | PENDING |
| `NFR-WORD-002` | ADR-0005 | Version the independent Unicode word-boundary implementation. | P04, P15 | Version-field and counter-vector test | P15 evidence | SATISFIED |
| `NFR-CTX-001` | ADR-0005 | Track the public 24 MB binary claim only as non-gating context. | P15, FINAL | Claim-classification audit | Release evidence | PENDING |
| `NFR-CTX-002` | ADR-0005 | Track the public 160 MB RAM claim only as non-gating context. | P15, FINAL | Claim-classification audit | Release evidence | PENDING |
| `NFR-CTX-003` | ADR-0005 | Track the public 106,322-word vocabulary claim only as non-gating context. | P15, FINAL | Claim-classification audit | Release evidence | PENDING |
| `NFR-CTX-004` | ADR-0005 | Keep those public claims non-gating until a reproducible like-for-like workload exists. | P15, FINAL | Release-gate configuration audit | Release evidence | PENDING |
| `NFR-HOLD-007` | ADR-0005 | Prohibit accuracy work from inspecting held-out cases after freeze. | P02-P15 | Access and artifact audit | Phase evidence | PENDING |
| `NFR-HOLD-008` | ADR-0005 | Expose post-freeze held-out performance only through aggregate release-gate results. | P15 | Output-surface audit | P15 evidence | PENDING |
| `NFR-HOLD-009` | ADR-0005 | Permit post-freeze error analysis only through the controlled protocol. | P15 | Error-analysis authorization audit | P15 evidence | PENDING |
| `NFR-TPUT-004` | ADR-0005 | Do not let repeated trivial input satisfy a throughput gate. | P15 | Trivial-input mutation test | P15 evidence | PENDING |
| `NFR-TPUT-005` | ADR-0005 | Do not let fast failure satisfy a throughput gate. | P15 | Failure-path mutation test | P15 evidence | PENDING |
| `NFR-TPUT-006` | ADR-0005 | Do not let aggregate throughput hide a failing performance stratum. | P15 | Aggregate-only negative test | P15 evidence | PENDING |
| `NFR-MEAS-008` | ADR-0005 | Do not let core throughput hide slow end-to-end integration behavior. | P15 | Independent-gate test | P15 evidence | PENDING |
| `NFR-MEAS-009` | ADR-0008 | Require performance measurements to be statistically repeatable. | P15 | Repeated-benchmark statistical comparison | P15 evidence | PENDING |
| `NFR-MEAS-010` | ADR-0008 | Do not require performance timings to be byte-identical or numerically identical. | P15 | Timing-variation acceptance test | P15 evidence | PENDING |
| `NFR-MEAS-011` | ADR-0008 | Pin the hardware configuration for every reported benchmark. | P15 | Hardware-identity manifest and substitution test | P15 evidence | PENDING |
| `NFR-MEAS-012` | ADR-0008 | Pin the software configuration for every reported benchmark. | P15 | Software-identity manifest and substitution test | P15 evidence | PENDING |
| `NFR-MEAS-013` | ADR-0008 | Isolate benchmark execution cores when the reference platform permits it. | P15 | Affinity configuration and capability report | P15 evidence | PENDING |
| `NFR-MEAS-014` | ADR-0008 | Publish a spread statistic for benchmark samples. | P15 | Raw-sample recomputation | P15 evidence | PENDING |
| `NFR-MEAS-015` | ADR-0008 | Repeat benchmarks to test statistical repeatability. | P15 | Independent repeated-run audit | P15 evidence | PENDING |
| `NFR-MEAS-016` | ADR-0008 | Assign every measurement reproducibility failure to its named envelope. | P15-P16, FINAL | Failure-classification scenarios | Reproducibility evidence | PENDING |
| `NFR-MEAS-017` | ADR-0008 | Do not weaken the semantic, adapter, build, or measurement envelope. | P01-P16, FINAL | ADR and requirement-delta audit | Decision evidence | PENDING |
| `NFR-MEAS-018` | ADR-0008 | Replace an implementation that cannot satisfy its applicable deterministic or reproducibility envelope. | P01-P16, FINAL | Nonconforming-implementation replacement test | Release evidence | PENDING |
| `NFR-MEAS-019` | ADR-0008 | Explicitly remove from release scope an implementation that is not replaced after failing its applicable envelope. | P01-P16, FINAL | Release-scope exclusion test | Release evidence | PENDING |
| `NFR-ROLL-001` | ADR-0005 | Permit quality and performance thresholds to change only by becoming stricter. | P00-P15 | ADR-delta threshold audit | Decision evidence | PENDING |
| `NFR-ROLL-002` | ADR-0005 | Invalidate affected results when a dataset defect is found. | P02, P15 | Defect-response scenario | P15 evidence | PENDING |
| `NFR-ROLL-003` | ADR-0005 | Invalidate affected results when an oracle defect is found. | P02, P15 | Defect-response scenario | P15 evidence | PENDING |
| `NFR-ROLL-004` | ADR-0005 | Require a new reviewed, frozen evaluation version after a dataset defect. | P02 | Re-freeze workflow test | P02 evidence | SATISFIED |
| `NFR-ROLL-005` | ADR-0005 | Require a new reviewed, frozen evaluation version after an oracle defect. | P02 | Re-freeze workflow test | P02 evidence | SATISFIED |

## Component boundary requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `ARC-CORE-001` | Steering 7 | Keep concrete languages out of `nlu-core`. | P01 | Dependency/source inspection | P01 evidence | SATISFIED |
| `ARC-CORE-002` | ADR-0008 | Prevent `nlu-core` from accessing the network. | P01 | Dependency/source audit and network-denied execution | P01 evidence | SATISFIED |
| `ARC-CORE-003` | ADR-0002 | Prohibit the core from executing or directly invoking a Home Assistant service. | P01-P14 | Dependency, callback, and call-graph audit | Security evidence | PENDING |
| `ARC-LANG-001` | Steering 7 | Keep only provenanced PT-BR behavior in `lang-ptbr`. | P04-P08 | Rule/data audit | Linguistic evidence | PENDING |
| `ARC-LANG-002` | ADR-0007 | Keep network clients and network-capable dependencies out of `lang-ptbr`. | P04-P08, P13 | Dependency, source, and network-capability audit | P13 evidence | PENDING |
| `ARC-DATA-001` | Steering 7 | Make data import fail closed. | P03, P06 | Corruption tests | P06 evidence | SATISFIED |
| `ARC-INTENT-001` | Steering 7 | Keep execution out of `intent-engine`. | P09 | Dependency/source inspection | P09 evidence | PENDING |
| `ARC-RESOLVE-001` | Steering 7 | Resolve against immutable catalog snapshots. | P10 | Reload/generation tests | P10 evidence | PENDING |
| `ARC-DIALOG-001` | Steering 7 | Keep dialogue memory bounded and session-isolated. | P12 | Resource/isolation tests | P12 evidence | SATISFIED |
| `ARC-POLICY-001` | Steering 7 | Make policy deny by default. | P13 | Exhaustive policy tests | P13 evidence | PENDING |
| `ARC-PROTO-001` | Steering 7 | Version every protocol DTO. | P01, P13 | Decode/version tests | P13 evidence | PENDING |
| `ARC-PROTO-002` | ADR-0007 | Keep core semantic outcomes unchanged across adapter-protocol upgrades. | P13-P15 | Cross-version core-outcome comparison | P15 evidence | PENDING |
| `ARC-PROTO-003` | ADR-0007 | Confine adapter-protocol upgrades to the two adapter halves and the server boundary. | P13-P15 | Dependency and cross-version call-graph audit | P15 evidence | PENDING |
| `ARC-SERVER-001` | Steering 7 | Permit server listeners but prohibit server outbound clients. | P13 | Process/network tests | P13 evidence | PENDING |
| `ARC-HA-001` | ADR-0002, ADR-0007 | Make the two adapter halves the only holders of Home Assistant authority and keep every other component authority-free. | P01-P14 | Authority-bearing type, credential, dependency, and call-graph audit | Security evidence | PENDING |
| `ARC-RESP-001` | Steering 7 | Use only deterministic provenanced response templates. | P14 | Template provenance snapshots | P14 evidence | PENDING |
| `ARC-RESP-002` | Steering 7 | Prohibit free-form generated response text. | P14 | Renderer dependency and output audit | P14 evidence | PENDING |

## Data and review requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `AUT-OPS-001` | Steering 5 | Decide reversible local development matters without requesting user input. | All | Decision-ledger audit | Phase evidence | PENDING |
| `AUT-OPS-002` | Steering 5 | Never publish autonomously. | All | Publication audit | Final evidence | PENDING |
| `AUT-OPS-003` | Steering 5 | Never push autonomously. | All | Remote-ref audit | Final evidence | PENDING |
| `AUT-OPS-004` | Steering 5 | Never deploy autonomously. | All | Deployment audit | Final evidence | PENDING |
| `AUT-OPS-005` | Steering 5 | Never purchase autonomously. | All | Purchase audit | Final evidence | PENDING |
| `AUT-OPS-006` | Steering 5 | Never accept a contract autonomously. | All | Contract-acceptance audit | Final evidence | PENDING |
| `AUT-OPS-007` | Steering 5 | Never use a real credential autonomously. | All | Credential-use audit | Final evidence | PENDING |
| `AUT-DEC-001` | Steering 5.1 | Apply the exact documented decision-priority order. | All | Decision-ledger priority test | Phase evidence | PENDING |
| `AUT-DEC-002` | Steering 5.2 | Convert every open or human-gated development decision into an autonomous task. | All | Decision-register state test | Phase evidence | PENDING |
| `AUT-DEC-003` | Steering 5.2 | Gather requirements and public evidence for every autonomous decision. | All | Decision research report | Phase evidence | PENDING |
| `AUT-DEC-004` | Steering 5.2 | Compare at least two routes and their tests for every autonomous decision. | All | Architecture alternatives audit | Phase evidence | PENDING |
| `AUT-DEC-005` | Steering 5.2 | Adversarially challenge every compared decision route. | All | Decision adversary report | Phase evidence | PENDING |
| `AUT-DEC-006` | Steering 5.2 | Select the decision route by the documented priority order. | All | Decision rationale audit | Phase evidence | PENDING |
| `AUT-DEC-007` | Steering 5.2 | Record a structural autonomous decision in an accepted ADR with alternatives, consequences, and rollback. | All | ADR schema and status check | Phase evidence | PENDING |
| `AUT-DEC-008` | Steering 5.2 | Materialize every autonomous decision in executable tests. | All | Decision-to-test trace | Phase evidence | PENDING |
| `AUT-DEC-009` | Steering 5.2 | Mark each decided item resolved and continue the queue. | All | Decision and queue transition test | Phase evidence | PENDING |
| `AUT-IMP-001` | Steering 5.3 | Confirm every impediment root cause with evidence. | All | Impediment-ledger evidence check | Phase evidence | PENDING |
| `AUT-IMP-002` | Steering 5.3 | Try at least two safe solutions for an impediment when applicable. | All | Attempt-count and applicability audit | Phase evidence | PENDING |
| `AUT-IMP-003` | Steering 5.3 | Obtain an independent alternative for every unresolved impediment. | All | Independent alternative report | Phase evidence | PENDING |
| `AUT-IMP-004` | Steering 5.3 | Restrict only the capability affected by an impediment. | All | Scope-delta audit | Phase evidence | PENDING |
| `AUT-IMP-005` | Steering 5.3 | Continue work that does not depend on an impediment. | All | Queue chronology audit | Phase evidence | PENDING |
| `AUT-IMP-006` | Steering 5.3 | Record impediment attempts, impact, and next action. | All | Impediment-ledger schema check | Phase evidence | PENDING |
| `AUT-IMP-007` | Steering 5.3 | Resume an impeded item as soon as a compatible route exists. | All | Queue resumption test | Phase evidence | PENDING |
| `AUT-IMP-008` | Steering 5.3 | Reject an ambiguously licensed candidate rather than blocking the project. | All | License-blocker scenario test | Phase evidence | PENDING |
| `AUT-IMP-009` | Steering 5.3 | Replace an unavailable real API with a faithful contract and mock. | All | API-unavailability scenario test | Phase evidence | PENDING |
| `AUT-IMP-010` | Steering 5.3 | Replace an absent optional tool with a compatible local alternative. | All | Tool-unavailability scenario test | Phase evidence | PENDING |
| `AUT-IMP-011` | Steering 5.3 | Measure a corpus-free strategy when a nonessential corpus is unavailable. | All | Corpus-unavailability benchmark | Phase evidence | PENDING |
| `AUT-IMP-012` | Steering 5.3 | Treat a test failure as remediation work rather than a terminal blocker. | All | Failure-state transition test | Phase evidence | PENDING |
| `RUN-QUAL-001` | Steering 2 | Give quality priority over cost, speed, and token volume. | All | Execution-decision and tradeoff audit | Phase evidence | PENDING |
| `RUN-QUAL-002` | Steering 2 | Give correctness priority over cost, speed, and token volume. | All | Execution-decision and tradeoff audit | Phase evidence | PENDING |
| `RUN-QUAL-003` | Steering 2 | Give evidence priority over cost, speed, and token volume. | All | Execution-decision and tradeoff audit | Phase evidence | PENDING |
| `RUN-QUAL-004` | Steering 2 | Never reduce test depth to save execution resources. | All | Test-scope and resource-decision audit | Phase evidence | PENDING |
| `RUN-QUAL-005` | Steering 2 | Never reduce source research to save execution resources. | All | Research-scope and resource-decision audit | Phase evidence | PENDING |
| `RUN-QUAL-006` | Steering 2 | Never reduce the required reviewer count to save execution resources. | All | Required-role and dispatch-count audit | Review evidence | PENDING |
| `RUN-QUAL-007` | Steering 2 | Never reduce finding reproduction to save execution resources. | All | Finding-to-reproducer audit | Review evidence | PENDING |
| `RUN-QUAL-008` | Steering 2 | Never reduce analysis depth to save execution resources. | All | Analysis-scope and resource-decision audit | Phase evidence | PENDING |
| `RUN-EFF-001` | Steering 2 | Avoid preventable rework. | All | Change and remediation chronology audit | Phase evidence | PENDING |
| `RUN-EFF-002` | Steering 2 | Avoid unfocused oversized agent contexts. | All | Agent-brief scope audit | Phase evidence | PENDING |
| `RUN-EFF-003` | Steering 2 | Avoid duplicate reviews without a distinct hypothesis. | All | Review-purpose deduplication audit | Review evidence | PENDING |
| `RUN-EFF-004` | Steering 2 | Avoid speculative changes. | All | Requirement-to-change trace audit | Phase evidence | PENDING |
| `AGT-BRIEF-001` | Steering 2 | Give every substantial agent a narrow scope. | All | Agent-brief scope audit | Phase evidence | PENDING |
| `AGT-BRIEF-002` | Steering 2 | Give every substantial agent the evidence needed for its task. | All | Agent-brief evidence audit | Phase evidence | PENDING |
| `AGT-BRIEF-003` | Steering 2 | Give every substantial agent explicit acceptance criteria. | All | Agent-brief acceptance audit | Phase evidence | PENDING |
| `AGT-PROFILE-001` | Steering 2 | Use the configured `gpt-5.6-sol` maximum-reasoning profile for the executor and substantial agents. | All | Session and agent-dispatch metadata audit | Phase evidence | PENDING |
| `AGT-PROFILE-002` | Steering 2 | Inherit the executor profile when per-subagent effort selection is unavailable. | All | Agent-dispatch fallback audit | Phase evidence | PENDING |
| `AGT-PROFILE-003` | Steering 2 | Never replace a mandatory reviewer with a smaller model to reduce consumption. | All | Required-role model-profile audit | Review evidence | PENDING |
| `AGT-EXEC-001` | Steering 9 | Keep the executor responsible for the repository tree. | All | Agent-work ledger and Git-author audit | Phase evidence | PENDING |
| `AGT-EXEC-002` | Steering 9 | Keep the executor responsible for integrating delegated work. | All | Delegation-to-integration review trace | Phase evidence | PENDING |
| `AGT-EXEC-003` | Steering 9 | Keep final technical decisions with the executor. | All | Decision-authority audit | Phase evidence | PENDING |
| `AGT-SUB-001` | Steering 9 | Prohibit a subagent from declaring the project goal complete. | All | Subagent-output and terminal-state audit | Phase evidence | PENDING |
| `AGT-SUB-002` | Steering 9 | Prohibit a subagent from editing outside its assigned scope. | All | Assigned-scope-to-diff audit | Phase evidence | PENDING |
| `AGT-PRE-001` | Steering 9.1 | Keep every pre-phase analysis agent read-only. | All | Pre-phase agent change audit | Phase evidence | PENDING |
| `AGT-PRE-002` | Steering 9.1 | Give requirements, architecture, and adversarial pre-phase agents separate briefs. | All | Brief-identity and scope audit | Phase evidence | PENDING |
| `AGT-SYN-001` | Steering 9.1 | Require the executor to synthesize all three pre-phase analysis tracks. | All | Phase synthesis coverage audit | Phase evidence | PENDING |
| `AGT-SYN-002` | Steering 9.1 | Divide delegated implementation into independent workstreams. | All | Workstream dependency audit | Phase evidence | PENDING |
| `AGT-WRITE-001` | Steering 9.1 | Assign non-overlapping file ownership to writer agents. | All | Concurrent writer-scope intersection test | Phase evidence | PENDING |
| `AGT-WRITE-002` | Steering 9.1 | Define explicit integration criteria for every writer-agent task. | All | Writer brief schema audit | Phase evidence | PENDING |
| `AGT-WRITE-003` | Steering 9.1 | Require executor review of all agent-produced code before integration. | All | Agent commit-to-review chronology audit | Phase evidence | PENDING |
| `AGT-EDIT-001` | AGENTS.md | Use `apply_patch` for every manual repository file edit. | All | Edit-tool trace audit with mechanical-rewrite classification | Phase evidence | PENDING |
| `AGT-SEARCH-001` | AGENTS.md | Use `find` and `grep` for repository search when `rg` is unavailable. | All | Search-tool availability and command-trace audit | Phase evidence | PENDING |
| `DAT-ADM-001` | Steering 8 | Complete source-discovery review before admission. | P02 | Reviewer report | P02 evidence | SATISFIED |
| `DAT-ADM-002` | Steering 8 | Complete source-license review before admission. | P02 | Reviewer report | P02 evidence | SATISFIED |
| `DAT-ADM-003` | Steering 8 | Complete source-provenance review before admission. | P02 | Reviewer report | P02 evidence | SATISFIED |
| `DAT-ADM-004` | Steering 8 | Complete source-quality review before admission. | P02 | Reviewer report | P02 evidence | SATISFIED |
| `DAT-ADM-005` | Steering 8 | Complete source-adversary review before admission. | P02 | Reviewer report | P02 evidence | SATISFIED |
| `DAT-DISC-001` | Steering 8 | Discover source candidates only through official maintainers or publications. | P02 | Discovery-origin audit | P02 evidence | SATISFIED |
| `DAT-LIC-001` | Steering 8 | Review the complete license text before source admission. | P02 | Full-license hash and text audit | P02 evidence | SATISFIED |
| `DAT-LIC-002` | Steering 8 | Verify actual source rightsholders before admission. | P02 | Rightsholder evidence audit | P02 evidence | SATISFIED |
| `DAT-LIC-003` | Steering 8 | Enumerate every license obligation before admission. | P02 | Obligation inventory check | P02 evidence | SATISFIED |
| `DAT-LIC-004` | Steering 8 | Verify modification and commercial redistribution rights before admission. | P02 | Rights-scope test | P02 evidence | SATISFIED |
| `DAT-PROV-001` | Steering 8 | Verify an immutable source version before admission. | P02 | Revision resolution check | P02 evidence | SATISFIED |
| `DAT-PROV-002` | Steering 8 | Verify a canonical public source URL before admission. | P02 | Canonical URL and owner check | P02 evidence | SATISFIED |
| `DAT-PROV-003` | Steering 8 | Verify the exact source artifact SHA-256 before admission. | P02 | Corrupt-artifact negative test | P02 evidence | SATISFIED |
| `DAT-PROV-004` | Steering 8 | Verify the exact source artifact byte size before admission. | P02 | Size mismatch negative test | P02 evidence | SATISFIED |
| `DAT-PROV-005` | Steering 8 | Verify a deterministic acquisition recipe before admission. | P02 | Clean acquisition replay | P02 evidence | SATISFIED |
| `DAT-QUAL-001` | Steering 8 | Review a source's domain before admission. | P02 | Quality-review schema check | P02 evidence | SATISFIED |
| `DAT-QUAL-002` | Steering 8 | Review a source's coverage before admission. | P02 | Coverage report audit | P02 evidence | SATISFIED |
| `DAT-QUAL-003` | Steering 8 | Review a source's annotation process before admission. | P02 | Annotation evidence audit | P02 evidence | SATISFIED |
| `DAT-QUAL-004` | Steering 8 | Review a source's available split boundaries before admission. | P02 | Split-evidence audit | P02 evidence | SATISFIED |
| `DAT-QUAL-005` | Steering 8 | Review a source's noise properties before admission. | P02 | Noise evidence audit | P02 evidence | SATISFIED |
| `DAT-QUAL-006` | Steering 8 | Record a source's quality limitations before admission. | P02 | Limitation-field check | P02 evidence | SATISFIED |
| `DAT-ADV-001` | Steering 8 | Adversarially challenge a source's license before admission. | P02 | License counterexample report | P02 evidence | SATISFIED |
| `DAT-ADV-002` | Steering 8 | Adversarially challenge a source's independence before admission. | P02 | Independence counterexample report | P02 evidence | SATISFIED |
| `DAT-ADV-003` | Steering 8 | Adversarially challenge a source's quality before admission. | P02 | Quality counterexample report | P02 evidence | SATISFIED |
| `DAT-ADV-004` | Steering 8 | Adversarially challenge a source's leakage boundaries before admission. | P02 | Leakage counterexample report | P02 evidence | SATISFIED |
| `DAT-MAN-001` | Steering 8 | Record a stable source identifier. | P02, P03 | Manifest field and uniqueness test | P03 evidence | SATISFIED |
| `DAT-MAN-002` | Steering 8 | Record the exact source admission status. | P02, P03 | Manifest state-domain test | P03 evidence | SATISFIED |
| `DAT-MAN-003` | Steering 8 | Record `USER_DELEGATED_AUTONOMY` as the admission basis. | P02, P03 | Manifest constant test | P03 evidence | SATISFIED |
| `DAT-MAN-004` | Steering 8 | Record the canonical public source URL. | P02, P03 | Manifest URL validation | P03 evidence | SATISFIED |
| `DAT-MAN-005` | Steering 8 | Record the upstream source owner. | P02, P03 | Owner admission check | P03 evidence | SATISFIED |
| `DAT-MAN-006` | Steering 8 | Record an immutable source version. | P02, P03 | Revision format and resolution test | P03 evidence | SATISFIED |
| `DAT-MAN-007` | Steering 8 | Record the exact source artifact SHA-256. | P02, P03 | Hash field and byte verification | P03 evidence | SATISFIED |
| `DAT-MAN-008` | Steering 8 | Record the exact source artifact size. | P02, P03 | Size field and byte verification | P03 evidence | SATISFIED |
| `DAT-MAN-009` | Steering 8 | Record the source SPDX license expression. | P02, P03 | SPDX policy validation | P03 evidence | SATISFIED |
| `DAT-MAN-010` | Steering 8 | Record the official license URL. | P02, P03 | License URL validation | P03 evidence | SATISFIED |
| `DAT-MAN-011` | Steering 8 | Record the complete license-text SHA-256. | P02, P03 | License byte verification | P03 evidence | SATISFIED |
| `DAT-MAN-012` | Steering 8 | Record the bounded intended source use. | P02, P03 | Intended-use policy test | P03 evidence | SATISFIED |
| `DAT-MAN-013` | Steering 8 | Record the source redistribution policy. | P02, P03 | Redistribution policy audit | P03 evidence | SATISFIED |
| `DAT-MAN-014` | Steering 8 | Record a versioned source fetch recipe. | P02, P03 | Fetch replay | P03 evidence | SATISFIED |
| `DAT-MAN-015` | Steering 8 | Record a versioned source extraction recipe. | P02, P03 | Extraction replay | P03 evidence | SATISFIED |
| `DAT-MAN-016` | Steering 8 | Record the anti-leakage split policy. | P02, P03 | Split replay | P03 evidence | SATISFIED |
| `DAT-MAN-017` | Steering 8 | Record all five required source-review identities. | P02, P03 | Reviewer-set exactness test | P03 evidence | SATISFIED |
| `DAT-MAN-018` | Steering 8 | Record the accepted source decision ADR. | P02, P03 | ADR path, status, and linkage test | P03 evidence | SATISFIED |
| `DAT-MAN-019` | AGENTS.md, SOURCE-POLICY.md | Record a versioned deterministic normalization recipe. | P02, P03 | Normalization recipe deletion and clean replay | P03 evidence | SATISFIED |
| `DAT-MAN-020` | AGENTS.md, SOURCE-POLICY.md | Record a versioned deterministic compilation recipe. | P02, P03 | Compilation recipe deletion and clean replay | P03 evidence | SATISFIED |
| `DAT-MAN-021` | AGENTS.md, SOURCE-POLICY.md | Record a versioned selective-removal recipe for the source and every derivative. | P02, P03 | Removal recipe deletion and selective-removal replay | P03 evidence | SATISFIED |
| `DAT-MAN-022` | AGENTS.md, SOURCE-POLICY.md | Record ordered transformation lineage with immutable transform identities and output hashes. | P02, P03 | Lineage-field deletion and transform/output substitution tests | P03 evidence | SATISFIED |
| `DAT-MAN-023` | AGENTS.md, SOURCE-POLICY.md | Record the license expression and obligations for every transformed output and derivative. | P02, P03 | Derivative-license deletion and policy audit | P03 evidence | SATISFIED |
| `DAT-MAN-024` | AGENTS.md, SOURCE-POLICY.md | Record the per-entry provenance schema used whenever multiple sources are merged. | P02, P03 | Merged-entry provenance deletion and ambiguity tests | P03 evidence | SATISFIED |
| `DAT-PROM-001` | Steering 8 | Require all five source reviews before promotion from quarantine. | P02 | Admission chronology test | P02 evidence | SATISFIED |
| `DAT-PROM-002` | Steering 8 | Require executor verification before source promotion. | P02 | Executor attestation check | P02 evidence | SATISFIED |
| `DAT-PROM-003` | Steering 8 | Reject any assumed or missing source-manifest field. | P02, P03 | Per-field deletion mutations | P03 evidence | SATISFIED |
| `DAT-PROM-004` | Steering 8 | Reject an unprovable license and continue searching for another source. | P02 | Rejection and queue transition test | P02 evidence | SATISFIED |
| `DAT-SPLIT-001` | Steering 6, 8 | Split data by a documented anti-leakage group. | P02, P03 | Split validator | P03 evidence | SATISFIED |
| `DAT-REMOVE-001` | Steering 8 | Remove every derivative contribution by source ID. | P03, P06 | Selective-removal test | P06 evidence | SATISFIED |
| `REV-PRE-001` | Steering 9.1 | Run independent pre-phase requirements analysis. | All | Phase report link | Phase evidence | PENDING |
| `REV-PRE-002` | Steering 9.1 | Run independent pre-phase architecture analysis. | All | Phase report link | Phase evidence | PENDING |
| `REV-PRE-003` | Steering 9.1 | Run independent pre-phase adversarial analysis. | All | Phase report link | Phase evidence | PENDING |
| `REV-POST-001` | Steering 9.2 | Run a read-only requirements review after every phase. | All | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-POST-002` | Steering 9.2 | Run a read-only correctness review after every phase. | All | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-POST-003` | Steering 9.2 | Run a read-only test-oracle review after every phase. | All | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-POST-004` | Steering 9.2 | Run a read-only risk review after every phase. | All | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-POST-005` | Steering 9.2 | Run a read-only reproducibility review after every phase. | All | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-POST-006` | Steering 9.2 | Run a read-only linguistics review in P02 and P04 through P12. | P02, P04-P12 | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-POST-007` | Steering 9.2 | Run a read-only runtime-adversarial review in P12 through P16. | P12-P16 | Exact-baseline reviewer report | Review evidence | PENDING |
| `REV-REPORT-001` | Steering 9.2 | Bind every reviewer report to an exact commit and tree. | All | Report schema validation | Review evidence | PENDING |
| `REV-REPORT-002` | Steering 9.2 | Require reproducible positive evidence in every reviewer report. | All | Report content validation | Review evidence | PENDING |
| `REV-REPORT-003` | Steering 9.2, AGENTS.md | Permit only PASS or FAIL verdicts in phase review reports; terminal tribunal reports are governed separately. | All | Phase-report verdict validation and terminal-report separation test | Review evidence | PENDING |
| `REV-REPORT-004` | ADR-0006 | Require every review report to declare its role. | All | Missing and unknown-role mutations | Review evidence | PENDING |
| `REV-REPORT-005` | ADR-0006 | Require every review report to identify its reviewer instance. | All | Missing and malformed-instance mutations | Review evidence | PENDING |
| `REV-REPORT-006` | ADR-0006 | Require every review report to declare independent context. | All | Missing and false-declaration mutations | Review evidence | PENDING |
| `REV-REPORT-007` | ADR-0006 | Require every review report to state its bounded scope. | All | Missing and empty-scope mutations | Review evidence | PENDING |
| `REV-REPORT-008` | ADR-0006 | Require every review report to list executed commands. | All | Missing and empty-command mutations plus replay | Review evidence | PENDING |
| `REV-REPORT-009` | ADR-0006 | Require every review report to contain findings or exact `None.`. | All | Missing and malformed-findings mutations | Review evidence | PENDING |
| `REV-REPORT-010` | ADR-0006 | Reject a review report generated against a dirty worktree. | All | Dirty-review-worktree test | Review evidence | PENDING |
| `REV-EVID-001` | Steering 9.2 | Require every reviewer to ignore the phase report's conclusion. | All | Reviewer-method declaration and conclusion-substitution test | Review evidence | PENDING |
| `REV-EVID-002` | Steering 9.2 | Require every reviewer to inspect primary evidence. | All | Primary-evidence citation audit | Review evidence | PENDING |
| `REV-EVID-003` | Steering 9.2 | Require every reviewer to cite inspected paths. | All | Report path-citation schema | Review evidence | PENDING |
| `REV-EVID-004` | Steering 9.2 | Require every reviewer to cite executed commands. | All | Report command replay | Review evidence | PENDING |
| `REV-EVID-005` | Steering 9.2 | Require every reviewer to cite review inputs. | All | Report input-citation schema | Review evidence | PENDING |
| `REV-EVID-006` | Steering 9.2 | Require every reviewer to cite reproducible command results. | All | Report-result replay | Review evidence | PENDING |
| `REV-EVID-007` | Steering 9.2 | Require every reviewer to attempt a counterexample. | All | Counterexample-attempt field audit | Review evidence | PENDING |
| `REV-EVID-008` | Steering 9.2 | Require every finding to be classified as P0, P1, P2, or P3. | All | Finding-severity domain test | Review evidence | PENDING |
| `REV-EVID-009` | Steering 9.2 | Prohibit every reviewer from editing during review. | All | Reviewer worktree and commit audit | Review evidence | PENDING |
| `REV-ADJ-001` | Steering 9.2 | Reproduce conflicting review claims through an independent adjudicator instead of voting. | All | Adjudication report and reproducer | Review evidence | PENDING |
| `REV-SEV-001` | Steering 9.2 | Block a phase on every open P0, P1, or P2. | All | Finding ledger check | Phase evidence | PENDING |
| `REV-INDEP-001` | Steering 9.3 | Prevent an implementer from being the sole reviewer. | All | Author/reviewer declaration | Review evidence | PENDING |
| `REV-INDEP-002` | Steering 9.3 | Use fresh sequential review contexts when parallel subagents are unavailable. | All | Reviewer-context declaration | Review evidence | PENDING |
| `REV-BASE-001` | Steering 10 | Bind every phase review to one commit and tree. | All | Baseline comparison | Review evidence | PENDING |
| `REV-BASE-002` | ADR-0006 | Include the complete phase implementation in the immutable review subject. | All | Subject-tree scope audit | Review evidence | PENDING |
| `REV-BASE-003` | ADR-0006 | Include the complete phase test delta in the immutable review subject. | All | Subject-tree test audit | Review evidence | PENDING |
| `REV-BASE-004` | ADR-0006 | Include every phase decision record in the immutable review subject. | All | Subject-tree ADR audit | Review evidence | PENDING |
| `REV-BASE-005` | ADR-0006 | Include pre-review evidence in the immutable review subject. | All | Subject-tree evidence audit | Review evidence | PENDING |
| `REV-BASE-006` | ADR-0006 | Keep every immutable review subject in `REVIEWING` state. | All | Subject-state mutation test | Review evidence | PENDING |
| `REV-BASE-007` | ADR-0006 | Produce reviewer reports outside the immutable subject tree. | All | Subject-tree and report chronology audit | Review evidence | PENDING |
| `REV-CHECK-001` | ADR-0006 | Require every applicable reviewer to agree before copying reports into the repository. | All | Review-verdict chronology test | Review evidence | PENDING |
| `REV-CHECK-002` | ADR-0006 | Require every applicable reviewer to agree before updating phase state or queue. | All | State-transition chronology test | Review evidence | PENDING |
| `REV-CHECK-003` | ADR-0006 | Require every applicable reviewer to agree before creating an evidence checkpoint. | All | Checkpoint-parent chronology test | Review evidence | PENDING |
| `REV-CHECK-004` | ADR-0006 | Correct an invalid evidence checkpoint only with a new corrective commit. | All | Approved-history non-rewrite test | Review evidence | PENDING |
| `REV-CHECK-005` | ADR-0006 | Re-review the last substantive candidate after an invalid evidence checkpoint. | All | Corrective-commit and review-baseline audit | Review evidence | PENDING |
| `REV-REMED-001` | Steering 10 | Add regression evidence for every remediated true finding. | All | Finding-to-test trace | Phase evidence | PENDING |
| `REV-P3-001` | Steering 9.2 | Retain a P3 as residual only when it cannot affect correctness, security, operation, license, or a requirement. | All | Residual-risk impact audit | Review evidence | PENDING |
| `REV-FP-001` | Steering 9.2 | Give every rejected false-positive finding a reproducible justification. | All | Adjudication reproducer | Review evidence | PENDING |
| `PHASE-LOOP-001` | Steering 10 | Inspect the current requirements and state before each phase delta. | All | Ordered phase ledger | Phase evidence | PENDING |
| `PHASE-LOOP-002` | Steering 10 | Map explicit acceptance criteria for every phase. | All | Acceptance-matrix check | Phase evidence | PENDING |
| `PHASE-LOOP-003` | Steering 10 | Map a threat and failure model for every phase. | All | Threat-model presence and scope check | Phase evidence | PENDING |
| `PHASE-LOOP-004` | Steering 10 | Compare implementation alternatives before each structural design. | All | Design-alternatives audit | Phase evidence | PENDING |
| `PHASE-LOOP-005` | Steering 10 | Record every structural design decision in an ADR. | All | Phase-to-ADR trace | Phase evidence | PENDING |
| `PHASE-LOOP-006` | Steering 10 | Implement the smallest complete integrated phase change. | All | Scope and integration audit | Phase evidence | PENDING |
| `PHASE-LOOP-007` | Steering 10 | Run targeted tests before freezing a phase. | All | Targeted-command evidence | Phase evidence | PENDING |
| `PHASE-LOOP-008` | Steering 10 | Run negative tests before freezing a phase. | All | Negative-command evidence | Phase evidence | PENDING |
| `PHASE-LOOP-009` | Steering 10 | Run every applicable common check before freezing a phase. | All | Common-check evidence | Phase evidence | PENDING |
| `PHASE-LOOP-010` | Steering 10 | Reproduce every review finding before disposition. | All | Finding reproducer | Phase evidence | PENDING |
| `PHASE-LOOP-011` | Steering 10 | Deduplicate findings without losing distinct obligations. | All | Finding-ledger identity audit | Phase evidence | PENDING |
| `PHASE-LOOP-012` | Steering 10 | Preserve the highest plausible severity during finding triage. | All | Severity transition audit | Phase evidence | PENDING |
| `PHASE-LOOP-013` | User, ADR-0006 | Defer an eligible P3 once minimum phase acceptance is met rather than extend the review loop. | All | Finding disposition and checkpoint chronology | Phase evidence | PENDING |
| `PHASE-LOOP-014` | Steering 10 | Rerun every check affected by a remediation. | All | Change-to-check trace | Phase evidence | PENDING |
| `PHASE-LOOP-015` | Steering 10 | Rerun all common checks after remediation. | All | Common-check rerun evidence | Phase evidence | PENDING |
| `PHASE-LOOP-016` | Steering 10 | Rerun every review role that failed or was affected. | All | Review rerun matrix | Review evidence | PENDING |
| `PHASE-LOOP-017` | Steering 10 | Gate a phase only with evidence bound to one baseline. | All | Gate baseline-equality test | Phase evidence | PENDING |
| `PHASE-LOOP-018` | Steering 10 | Update persistent project status at each checkpoint. | All | Checkpoint status transition test | Phase evidence | PENDING |
| `PHASE-LOOP-019` | Steering 10 | Update the autonomous queue at each checkpoint. | All | Checkpoint queue transition test | Phase evidence | PENDING |
| `PHASE-LOOP-020` | Steering 10 | Update the phase report at each checkpoint. | All | Report and state consistency test | Phase evidence | PENDING |
| `PHASE-LOOP-021` | Steering 10 | Commit each green phase checkpoint atomically. | All | Git parent and change-scope audit | Phase evidence | PENDING |
| `PHASE-LOOP-022` | Steering 10 | Enqueue and execute the next phase after a passed checkpoint. | All | Queue chronology and next-action audit | Phase evidence | PENDING |
| `STAG-001` | Steering 10 | Detect three consecutive attempts that leave the diagnosis unchanged. | All | Attempt-ledger counter test | Phase evidence | PENDING |
| `STAG-002` | Steering 10 | Run an independent stagnation-root-cause review after three unchanged diagnoses. | All | Root-cause reviewer report | Phase evidence | PENDING |
| `STAG-003` | Steering 10 | Run an independent alternative-design review after three unchanged diagnoses. | All | Alternative-design reviewer report | Phase evidence | PENDING |
| `STAG-004` | Steering 10 | Compare a materially new route after stagnation. | All | Route-difference audit | Phase evidence | PENDING |
| `STAG-005` | Steering 10 | Revert only owned non-green changes to the last approved baseline. | All | Git ownership audit | Phase evidence | PENDING |
| `STAG-006` | Steering 10 | Do not repeat the same failed route indefinitely. | All | Attempt-route audit | Phase evidence | PENDING |
| `STATE-SCHEMA-001` | Steering 11 | Persist the exact autonomous execution mode. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-002` | Steering 11 | Persist the fresh-implementation bootstrap mode. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-003` | Steering 11 | Persist the current phase. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-004` | Steering 11 | Persist the current phase state. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-005` | Steering 11 | Persist the immutable subject baseline. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-006` | Steering 11 | Persist the ordered completed-phase set. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-007` | Steering 11 | Persist open findings. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-008` | Steering 11 | Persist deferred external validations. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-009` | Steering 11 | Persist the last validation identity. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `STATE-SCHEMA-010` | Steering 11 | Persist the terminal state. | P00 | Project-status field mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-001` | Steering 11 | Persist `DEVELOPMENT_COMPLETE` as the queue goal. | P00 | Queue field mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-002` | Steering 11 | Persist an armed terminal guard before FINAL. | P00 | Queue field mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-003` | Steering 11 | Persist the active queue item. | P00 | Queue field mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-004` | Steering 11 | Persist a concrete executable next action. | P00 | Queue action-shape mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-005` | Steering 11 | Persist every remaining phase in order through FINAL. | P00 | Queue order mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-006` | Steering 11 | Persist waiting internal dependencies. | P00 | Queue field mutation | P00 evidence | SATISFIED |
| `QUEUE-SCHEMA-007` | Steering 11 | Persist the last checkpoint identity. | P00 | Queue field mutation | P00 evidence | SATISFIED |
| `STATE-END-001` | Steering 11, 16 | Update project status before every interruption. | All | Turn-end state audit | Phase evidence | PENDING |
| `STATE-END-002` | Steering 11, 16 | Update the autonomous queue before every interruption. | All | Turn-end queue audit | Phase evidence | PENDING |
| `STATE-END-003` | Steering 11 | Persist findings before every interruption. | All | Turn-end finding audit | Phase evidence | PENDING |
| `STATE-END-004` | Steering 11 | Persist executed commands before every interruption. | All | Turn-end command audit | Phase evidence | PENDING |
| `STATE-END-005` | Steering 11 | Persist a concrete small next action before every interruption. | All | Next-action shape test | Phase evidence | PENDING |
| `STATE-END-006` | Steering 11 | Commit the tree before interruption whenever it is green. | All | Git status and checkpoint audit | Phase evidence | PENDING |
| `STATE-END-007` | Steering 11, 16 | Emit exactly one allowed autonomous-run status marker before interruption. | All | Marker cardinality and domain test | Phase evidence | PENDING |
| `STATE-INT-001` | Steering 11 | Never convert quota, context, timeout, client crash, or transient tool failure into a project terminal state. | All | Interruption state-machine tests | Phase evidence | PENDING |
| `STATE-INT-002` | Steering 11, 16 | Persist resumable state after every operational interruption. | All | Interrupted-run recovery tests | Phase evidence | PENDING |
| `STATE-001` | Steering 11 | Persist one executable next action before every interruption. | All | State/queue validator | Phase state | PENDING |
| `CONT-GUARD-001` | Steering 11 | Run a read-only continuation guard after every review. | All | Guard report | Phase evidence | PENDING |
| `CONT-GUARD-002` | Steering 11 | Run a read-only continuation guard before any attempt to end work. | All | Guard report | Phase evidence | PENDING |
| `CONT-GUARD-003` | Steering 11 | Execute the concrete next action whenever the continuation guard returns CONTINUE. | All | Queue and action trace | Phase evidence | PENDING |
| `CONT-GUARD-004` | Steering 11 | Permit `CONTINUE` only with one concrete next action. | All | Guard parser mutation | Phase evidence | PENDING |
| `CONT-GUARD-005` | Steering 11 | Permit `TERMINAL_ALLOWED` only with complete terminal evidence. | All | Guard parser mutation | Final evidence | PENDING |
| `CONT-GUARD-006` | Steering 11 | Reject every continuation-guard output outside the two allowed forms. | All | Guard output-domain test | Phase evidence | PENDING |
| `CONT-GUARD-007` | Steering 11 | Refill an empty queue before FINAL instead of ending work. | All | Pre-FINAL empty-queue test | Phase evidence | PENDING |
| `VAL-CARGO-001` | Steering 12 | Run the exact workspace formatting check whenever a Cargo workspace exists. | P01-P16 | Exact command evidence | Phase evidence | PENDING |
| `VAL-CARGO-002` | Steering 12 | Run the exact all-target all-feature Clippy warnings-as-errors check whenever a Cargo workspace exists. | P01-P16 | Exact command evidence | Phase evidence | PENDING |
| `VAL-CARGO-003` | Steering 12 | Run the exact all-feature workspace test command whenever a Cargo workspace exists. | P01-P16 | Exact command evidence | Phase evidence | PENDING |
| `VAL-CARGO-004` | Steering 12 | Run the exact all-target workspace build command whenever a Cargo workspace exists. | P01-P16 | Exact command evidence | Phase evidence | PENDING |
| `VAL-TEST-001` | Steering 12 | Add unit tests progressively as behavior appears. | P01-P16 | Test inventory and sentinel | Phase evidence | PENDING |
| `VAL-TEST-002` | Steering 12 | Add integration tests progressively as boundaries appear. | P01-P16 | Test inventory and sentinel | Phase evidence | PENDING |
| `VAL-TEST-003` | Steering 12 | Add negative tests progressively as rejection behavior appears. | P01-P16 | Test inventory and sentinel | Phase evidence | PENDING |
| `VAL-TEST-004` | Steering 12 | Add canonical snapshot tests progressively as serialization appears. | P01-P16 | Test inventory and sentinel | Phase evidence | PENDING |
| `VAL-ADV-001` | Steering 12 | Audit dependency advisories progressively. | P01-P16 | Advisory report | Phase evidence | PENDING |
| `VAL-ORACLE-001` | Steering 12 | Never treat a substitute check as proof that the original check passed. | All | Evidence command-identity test | Phase evidence | PENDING |
| `VAL-ENV-001` | Steering 12 | Distinguish an environmental failure from a product failure. | All | Failure classification test | Phase evidence | PENDING |
| `VAL-ENV-002` | Steering 12 | Retain evidence for environmental and product failures. | All | Failure evidence schema | Phase evidence | PENDING |
| `VAL-ENV-003` | Steering 12 | Record a concrete resumption plan for every failed check. | All | Failure queue transition test | Phase evidence | PENDING |
| `TERM-BLK-001` | Steering 15.2 | Obtain terminal-evidence BLOCKED_CONFIRMED on the terminal baseline before entering TERMINAL_BLOCKED. | FINAL | Tribunal reviewer report | Terminal evidence | PENDING |
| `TERM-BLK-002` | Steering 15.2 | Obtain terminal-alternatives BLOCKED_CONFIRMED on the terminal baseline before entering TERMINAL_BLOCKED. | FINAL | Tribunal reviewer report | Terminal evidence | PENDING |
| `TERM-BLK-003` | Steering 15.2 | Obtain terminal-adversary BLOCKED_CONFIRMED on the terminal baseline before entering TERMINAL_BLOCKED. | FINAL | Tribunal reviewer report | Terminal evidence | PENDING |
| `TERM-BLK-004` | Steering 15.2 | Obtain terminal-scope-reducer BLOCKED_CONFIRMED on the terminal baseline before entering TERMINAL_BLOCKED. | FINAL | Tribunal reviewer report | Terminal evidence | PENDING |
| `TERM-BLK-005` | Steering 15.2 | Obtain terminal-legal-data BLOCKED_CONFIRMED on the terminal baseline before entering TERMINAL_BLOCKED. | FINAL | Tribunal reviewer report | Terminal evidence | PENDING |
| `TERM-BLK-006` | Steering 15.2 | Obtain terminal-engineering-fallback BLOCKED_CONFIRMED on the terminal baseline before entering TERMINAL_BLOCKED. | FINAL | Tribunal reviewer report | Terminal evidence | PENDING |
| `TERM-BLK-007` | Steering 15.2 | Require unanimous terminal tribunal confirmation on one exact baseline. | FINAL | Baseline and verdict audit | Terminal evidence | PENDING |
| `TERM-BLK-008` | Steering 15.2 | Record searches, attempts, fallback failures, and product-minimum proof in TERMINAL-TRIBUNAL.md. | FINAL | Tribunal artifact audit | Terminal evidence | PENDING |
| `TERM-BLK-009` | Steering 15.2 | Enter `TERMINAL_BLOCKED` only for an unavoidable external impossibility after every safe route fails. | FINAL | Tribunal reason and attempt audit | Terminal evidence | PENDING |
| `TERM-BLK-010` | Steering 15.2, AGENTS.md | Permit only BLOCKED_CONFIRMED verdicts in terminal tribunal reports and never treat them as phase review reports. | FINAL | Tribunal-report verdict and role-separation audit | Terminal evidence | PENDING |
| `TERM-NONBLOCK-001` | Steering 15.2 | Never treat a code failure as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-002` | Steering 15.2 | Never treat a test failure as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-003` | Steering 15.2 | Never treat a design failure as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-004` | Steering 15.2 | Never treat rejection of one source as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-005` | Steering 15.2 | Never treat a Git failure as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-006` | Steering 15.2 | Never treat absence of an optional tool as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-007` | Steering 15.2 | Never treat incomplete documentation as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-008` | Steering 15.2 | Never treat an unavailable real API as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-NONBLOCK-009` | Steering 15.2 | Never treat absent human approval as terminal. | FINAL | Terminal reason-code negative test | Terminal evidence | PENDING |
| `TERM-SCOPE-001` | Steering 15.2 | Require terminal-evidence to prove the external restriction. | FINAL | Tribunal role-scope schema | Terminal evidence | PENDING |
| `TERM-SCOPE-002` | Steering 15.2 | Require terminal-alternatives to search for substitutes. | FINAL | Tribunal role-scope schema | Terminal evidence | PENDING |
| `TERM-SCOPE-003` | Steering 15.2 | Require terminal-adversary to try to refute blockage. | FINAL | Tribunal role-scope schema | Terminal evidence | PENDING |
| `TERM-SCOPE-004` | Steering 15.2 | Require terminal-scope-reducer to preserve the minimum product. | FINAL | Tribunal role-scope schema | Terminal evidence | PENDING |
| `TERM-SCOPE-005` | Steering 15.2 | Require terminal-legal-data to search for a compatible source route. | FINAL | Tribunal role-scope schema | Terminal evidence | PENDING |
| `TERM-SCOPE-006` | Steering 15.2 | Require terminal-engineering-fallback to prototype a local alternative or mock. | FINAL | Tribunal role-scope schema | Terminal evidence | PENDING |
| `TERM-ART-001` | Steering 15.2 | Emit `docs/phases/TERMINAL-TRIBUNAL.md` only on the blocked route. | FINAL | Terminal artifact path audit | Terminal evidence | PENDING |
| `TERM-ART-002` | Steering 15.2 | Record terminal restriction evidence. | FINAL | Tribunal section mutation | Terminal evidence | PENDING |
| `TERM-ART-003` | Steering 15.2 | Record terminal substitute searches. | FINAL | Tribunal section mutation | Terminal evidence | PENDING |
| `TERM-ART-004` | Steering 15.2 | Record terminal engineering attempts. | FINAL | Tribunal section mutation | Terminal evidence | PENDING |
| `TERM-ART-005` | Steering 15.2 | Record why every safe fallback failed. | FINAL | Tribunal section mutation | Terminal evidence | PENDING |
| `TERM-ART-006` | Steering 15.2 | Prove that no fallback satisfies the minimum product. | FINAL | Minimum-product proof audit | Terminal evidence | PENDING |

## P01 foundation requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P01-TOOL-001` | ADR-0003 | Pin Rust 1.98.0 exactly in `rust-toolchain.toml`. | P01 | Toolchain-file and `rustc --version` audit | P01 evidence | SATISFIED |
| `P01-TOOL-002` | ADR-0003 | Set every Rust crate to Edition 2024. | P01 | Cargo manifest audit | P01 evidence | SATISFIED |
| `P01-LIC-001` | User | Admit every direct and transitive dependency under FOSS policy. | P01 | License/source audit | P01 evidence | SATISFIED |
| `P01-BOUND-001` | Steering P01 | Keep `nlu-core` standard-library-only initially. | P01 | Cargo graph check | P01 evidence | SATISFIED |
| `P01-BOUND-002` | Steering P01 | Make `protocol` depend on core without a reverse edge. | P01 | Cargo graph check | P01 evidence | SATISFIED |
| `P01-IN-001` | Steering P01, ADR-0003 | Define an immutable request input. | P01 | Mutation-denial and ownership tests | P01 evidence | SATISFIED |
| `P01-IN-002` | ADR-0008 | Define the semantic envelope over the same binary, configuration, language package, catalog snapshot revision, session snapshot, injected logical time, and request bytes. | P01 | Repeated semantic-envelope tests | P01 evidence | SATISFIED |
| `P01-SPAN-001` | Steering P01 | Reject out-of-range UTF-8 spans. | P01 | Span range negative tests | P01 evidence | SATISFIED |
| `P01-SPAN-002` | Steering P01 | Reject spans whose endpoints are not UTF-8 character boundaries. | P01 | Span boundary negative tests | P01 evidence | SATISFIED |
| `P01-SPAN-003` | ADR-0003 | Keep unchecked raw span offsets private. | P01 | Public API and source audit | P01 evidence | SATISFIED |
| `P01-SPAN-004` | ADR-0003 | Store span offsets in fixed-width unsigned values. | P01 | Type and overflow tests | P01 evidence | SATISFIED |
| `P01-ID-001` | Steering P01, ADR-0003 | Reject invalid stable identifier strings. | P01 | Identifier property tests | P01 evidence | SATISFIED |
| `P01-SCORE-001` | ADR-0003 | Represent core ranking values with bounded integers or fixed-point values. | P01 | Type, bound, and source audit | P01 evidence | SATISFIED |
| `P01-HYP-001` | Steering P01 | Give every hypothesis a stable intent identifier. | P01 | Constructor and round-trip tests | P01 evidence | SATISFIED |
| `P01-SLOT-001` | Steering P01 | Represent slot values as closed typed variants. | P01 | Type and hostile-decode tests | P01 evidence | SATISFIED |
| `P01-ENTITY-001` | Steering P01 | Represent entity references with stable identifiers. | P01 | Type and identifier tests | P01 evidence | SATISFIED |
| `P01-PLAN-001` | Steering P01 | Reject empty understood plans. | P01 | Constructor/decode negatives | P01 evidence | SATISFIED |
| `P01-PLAN-002` | Steering P01 | Reject duplicate plan graph references. | P01 | Duplicate-reference graph negatives | P01 evidence | SATISFIED |
| `P01-PLAN-003` | Steering P01 | Reject dangling plan graph references. | P01 | Dangling-reference graph negatives | P01 evidence | SATISFIED |
| `P01-PLAN-004` | ADR-0003 | Keep Home Assistant credentials out of plans. | P01 | Type and source audit | P01 evidence | SATISFIED |
| `P01-PLAN-005` | ADR-0003 | Keep raw Home Assistant service names out of plans. | P01 | Type and hostile-input audit | P01 evidence | SATISFIED |
| `P01-PLAN-006` | ADR-0003 | Keep unvalidated JSON payloads out of plans. | P01 | Type and hostile-input audit | P01 evidence | SATISFIED |
| `P01-PLAN-007` | ADR-0003 | Keep execution callbacks out of plans. | P01 | Type and dependency audit | P01 evidence | SATISFIED |
| `P01-CLAR-001` | Steering P01 | Give clarification options stable identifiers. | P01 | Round-trip tests | P01 evidence | SATISFIED |
| `P01-OUT-001` | Steering P01, ADR-0003 | Reject malformed outcome combinations in core constructors. | P01 | Constructor negative tests | P01 evidence | SATISFIED |
| `P01-TRAIT-001` | Steering P01, 6.2 | Inject logical time through an explicit trait. | P01 | Deterministic clock-fake tests | P01 evidence | SATISFIED |
| `P01-TRAIT-002` | Steering P01, 6.2 | Inject opaque identifier creation through an explicit trait. | P01 | Deterministic identifier-fake tests | P01 evidence | SATISFIED |
| `P01-ERR-001` | Steering P01, ADR-0004 | Define typed protocol error variants. | P01 | Exhaustive error-variant tests | P01 evidence | SATISFIED |
| `P01-ERR-002` | Steering P01 | Bound every protocol error representation. | P01 | Error-size boundary tests | P01 evidence | SATISFIED |
| `P01-ERR-003` | Steering P01 | Prevent protocol errors from echoing sensitive input. | P01 | Error leak-canary tests | P01 evidence | SATISFIED |
| `P01-LIMIT-001` | Steering P01, ADR-0004 | Define and enforce the request byte limit at construction boundaries. | P01 | Constructor boundary tests | P01 evidence | SATISFIED |
| `P01-LIMIT-002` | Steering P01, ADR-0004 | Define and enforce collection count limits at construction boundaries. | P01 | Constructor collection-boundary tests | P01 evidence | SATISFIED |
| `P01-LIMIT-003` | Steering P01 | Define and enforce nesting-depth limits at decode boundaries. | P01 | Hostile nesting tests | P01 evidence | SATISFIED |
| `P01-LIMIT-004` | ADR-0004 | Define and enforce string byte limits at decode boundaries. | P01 | Oversized-string tests | P01 evidence | SATISFIED |
| `P01-SER-001` | Steering P01 | Serialize equivalent values to identical JSON bytes. | P01 | Canonical byte tests | P01 evidence | SATISFIED |
| `P01-SER-002` | Steering P01 | Reject unknown JSON fields. | P01 | Unknown-field decode tests | P01 evidence | SATISFIED |
| `P01-SER-003` | Steering P01 | Reject duplicate JSON keys. | P01 | Duplicate-key decode tests | P01 evidence | SATISFIED |
| `P01-SER-004` | ADR-0004 | Reject trailing protocol input. | P01 | Trailing-input decode tests | P01 evidence | SATISFIED |
| `P01-SER-005` | ADR-0004 | Reject malformed UTF-8 protocol input. | P01 | Malformed UTF-8 decode tests | P01 evidence | SATISFIED |
| `P01-SER-006` | ADR-0004 | Emit canonical JSON fields in a fixed order. | P01 | Canonical byte snapshots | P01 evidence | SATISFIED |
| `P01-SER-007` | ADR-0004 | Emit stable canonical enum tags. | P01 | Enum-tag snapshots | P01 evidence | SATISFIED |
| `P01-SER-008` | ADR-0004 | Keep floating-point values out of protocol DTOs. | P01 | DTO type and schema audit | P01 evidence | SATISFIED |
| `P01-SER-009` | ADR-0004 | Keep semantically unordered JSON objects out of protocol DTOs. | P01 | DTO type and permutation audit | P01 evidence | SATISFIED |
| `P01-VER-001` | Steering P01 | Reject unsupported protocol versions. | P01 | Version negatives | P01 evidence | SATISFIED |
| `P01-VER-002` | ADR-0004 | Reject unknown outcome tags. | P01 | Outcome-tag negatives | P01 evidence | SATISFIED |
| `P01-SCHEMA-001` | ADR-0004 | Version every published JSON Schema. | P01 | Schema-version audit | P01 evidence | SATISFIED |
| `P01-SCHEMA-002` | ADR-0004 | Check versioned JSON Schemas against implementation fixtures. | P01 | Schema-fixture conformance tests | P01 evidence | SATISFIED |
| `P01-DET-001` | Steering 6.2 | Keep locale out of P01 output. | P01 | Locale permutation tests | P01 evidence | SATISFIED |
| `P01-DET-002` | Steering 6.2 | Keep timezone out of P01 output. | P01 | Timezone permutation tests | P01 evidence | SATISFIED |
| `P01-DET-003` | Steering 6.2 | Keep filesystem paths out of P01 output. | P01 | Working-directory permutation tests | P01 evidence | SATISFIED |
| `P01-DET-004` | Steering 6.2 | Keep map insertion order out of P01 output. | P01 | Insertion-order permutation tests | P01 evidence | SATISFIED |
| `P01-DET-005` | Steering 6.2 | Keep wall time out of P01 output. | P01 | Wall-clock denial tests | P01 evidence | SATISFIED |
| `P01-DET-006` | ADR-0008 | Prevent core semantic code from reading the process environment. | P01 | Environment-denied execution and source audit | P01 evidence | SATISFIED |
| `P01-DET-007` | ADR-0008 | Keep filesystem iteration order out of core semantics. | P01 | Filesystem-order permutation tests | P01 evidence | SATISFIED |
| `P01-DET-008` | ADR-0008 | Prevent core semantic code from reading global mutable state. | P01 | Global-state source audit and isolation tests | P01 evidence | SATISFIED |
| `P01-FIX-001` | Steering 6.1 | Use only non-language `FIXTURE_TECNICA` markers in P01 tests. | P01 | Fixture origin scan | P01 evidence | SATISFIED |
| `P01-GATE-001` | Steering P01 | Pass `cargo fmt --all -- --check`. | P01 | Executed `cargo fmt --all -- --check` | P01 evidence | SATISFIED |
| `P01-GATE-002` | Steering P01 | Pass Clippy with warnings denied. | P01 | Executed Clippy command | P01 evidence | SATISFIED |
| `P01-GATE-003` | Steering P01 | Pass all P01 tests. | P01 | Executed test command | P01 evidence | SATISFIED |
| `P01-GATE-004` | Steering P01 | Pass all-target builds. | P01 | Executed all-target build | P01 evidence | SATISFIED |
| `P01-PROTO-001` | ADR-0004 | Keep protocol DTOs distinct from core domain types. | P01 | Dependency and type audit | P01 evidence | SATISFIED |
| `P01-ORDER-001` | ADR-0003 | Use ordered vectors or sorted maps for every observably ordered collection. | P01 | Collection-type and permutation tests | P01 evidence | SATISFIED |
| `P01-TOOL-003` | ADR-0003 | Declare `rust-version = "1.98"` in the Cargo package configuration. | P01 | Cargo manifest audit | P01 evidence | SATISFIED |
| `P01-TOOL-004` | ADR-0003 | Version the resolved Cargo lockfile. | P01 | Git and lockfile audit | P01 evidence | SATISFIED |
| `P01-PROTO-002` | ADR-0003 | Validate every protocol DTO-to-core conversion before constructing a core value. | P01 | Conversion negative tests | P01 evidence | SATISFIED |
| `P01-IN-003` | ADR-0003 | Preserve the original UTF-8 request bytes as the immutable source of truth. | P01 | Byte-preservation tests | P01 evidence | SATISFIED |
| `P01-SPAN-005` | ADR-0003 | Interpret every span start as inclusive and every span end as exclusive. | P01 | Half-open slicing tests | P01 evidence | SATISFIED |
| `P01-SPAN-006` | ADR-0003 | Use UTF-8 byte offsets for core and wire span coordinates. | P01 | Multibyte-coordinate tests | P01 evidence | SATISFIED |
| `P01-SPAN-007` | ADR-0003 | Reject spans whose start offset exceeds their end offset. | P01 | Reversed-span negative tests | P01 evidence | SATISFIED |
| `P01-ID-002` | ADR-0003 | Keep stable identifiers opaque to consumers. | P01 | Public API and comparison-operation audit | P01 evidence | SATISFIED |
| `P01-ID-003` | ADR-0003 | Require every stable identifier to carry an explicit namespace. | P01 | Missing and invalid namespace tests | P01 evidence | SATISFIED |
| `P01-HYP-002` | Steering P01 | Give every hypothesis a deterministic score. | P01 | Repeated-construction tests | P01 evidence | SATISFIED |
| `P01-HYP-003` | Steering P01 | Give every hypothesis span evidence. | P01 | Constructor and round-trip tests | P01 evidence | SATISFIED |
| `P01-SLOT-002` | Steering P01 | Give every slot a stable slot identifier. | P01 | Identifier and round-trip tests | P01 evidence | SATISFIED |
| `P01-ENTITY-002` | Steering P01 | Bind every entity reference to an explicit catalog generation. | P01 | Missing and stale-generation tests | P01 evidence | SATISFIED |
| `P01-PLAN-008` | ADR-0003 | Represent plan nodes in an explicit deterministic order. | P01 | Node-order permutation tests | P01 evidence | SATISFIED |
| `P01-PLAN-009` | ADR-0003 | Represent plan slots with typed values. | P01 | Plan-constructor type tests | P01 evidence | SATISFIED |
| `P01-PLAN-010` | ADR-0003 | Carry checked evidence spans in plans. | P01 | Plan evidence-span tests | P01 evidence | SATISFIED |
| `P01-PLAN-011` | ADR-0003 | Carry validated entity references in plans. | P01 | Plan entity-reference tests | P01 evidence | SATISFIED |
| `P01-PLAN-012` | ADR-0003 | Represent graph relations as typed relations. | P01 | Relation-type and hostile-construction tests | P01 evidence | SATISFIED |
| `P01-PLAN-013` | ADR-0003 | Keep Home Assistant domain and action semantics extensible without closed exhaustive enums. | P01 | Extensibility and compatibility tests | P01 evidence | SATISFIED |
| `P01-SCORE-002` | ADR-0003 | Represent core confidence values with bounded integers or fixed-point values. | P01 | Type, bound, and source audit | P01 evidence | SATISFIED |
| `P01-OUT-002` | ADR-0003 | Reject malformed outcome combinations during DTO-to-core conversion. | P01 | DTO conversion negative tests | P01 evidence | SATISFIED |
| `P01-OUT-003` | ADR-0003 | Require every understood outcome to carry a non-empty valid plan. | P01 | Understood-outcome constructor and decode tests | P01 evidence | SATISFIED |
| `P01-TOOL-005` | ADR-0003 | Advance the exact Rust pin only through a tested ADR amendment. | P01 | Toolchain-change governance test | P01 evidence | SATISFIED |
| `P01-VER-009` | ADR-0003 | Preserve all core invariants across protocol-version changes. | P01 | Cross-version invariant tests | P01 evidence | SATISFIED |
| `P01-PROTO-003` | ADR-0004 | Use UTF-8 JSON as the protocol version 1 wire format. | P01 | Wire fixture and encoding tests | P01 evidence | SATISFIED |
| `P01-VER-003` | ADR-0004 | Require an explicit protocol version on every top-level request. | P01 | Missing-request-version tests | P01 evidence | SATISFIED |
| `P01-VER-004` | ADR-0004 | Require an explicit protocol version on every top-level response. | P01 | Response schema and serialization tests | P01 evidence | SATISFIED |
| `P01-DECODE-001` | ADR-0004 | Reject invalid identifiers during DTO-to-core conversion. | P01 | Invalid-identifier decode tests | P01 evidence | SATISFIED |
| `P01-DECODE-002` | ADR-0004 | Reject invalid spans during DTO-to-core conversion. | P01 | Invalid-span decode tests | P01 evidence | SATISFIED |
| `P01-DECODE-003` | ADR-0004 | Reject duplicate graph references during DTO-to-core conversion. | P01 | Duplicate-reference decode tests | P01 evidence | SATISFIED |
| `P01-DECODE-004` | ADR-0004 | Reject dangling graph references during DTO-to-core conversion. | P01 | Dangling-reference decode tests | P01 evidence | SATISFIED |
| `P01-DECODE-005` | ADR-0004 | Reject empty plans during DTO-to-core conversion. | P01 | Empty-plan decode tests | P01 evidence | SATISFIED |
| `P01-LIMIT-005` | ADR-0004 | Enforce the explicit request byte limit at decode boundaries. | P01 | Oversized-request decode tests | P01 evidence | SATISFIED |
| `P01-LIMIT-006` | ADR-0004 | Enforce explicit collection count limits at decode boundaries. | P01 | Oversized-collection decode tests | P01 evidence | SATISFIED |
| `P01-ERR-004` | Steering P01 | Keep protocol error variants closed. | P01 | Exhaustiveness and unknown-variant tests | P01 evidence | SATISFIED |
| `P01-ERR-005` | ADR-0004 | Prevent protocol errors from echoing complete hostile inputs. | P01 | Full-input leak-canary tests | P01 evidence | SATISFIED |
| `P01-BOUND-003` | ADR-0004 | Exclude transport selection from P01. | P01 | Dependency and source audit | P01 evidence | SATISFIED |
| `P01-BOUND-004` | ADR-0004 | Exclude framing selection from P01. | P01 | Dependency and source audit | P01 evidence | SATISFIED |
| `P01-BOUND-005` | ADR-0004 | Exclude authentication selection from P01. | P01 | Dependency and source audit | P01 evidence | SATISFIED |
| `P01-VER-005` | ADR-0004 | Require compatibility analysis before adding a protocol field. | P01 | Protocol-change governance test | P01 evidence | SATISFIED |
| `P01-VER-006` | ADR-0004 | Require compatibility analysis before relaxing a protocol limit. | P01 | Limit-change governance test | P01 evidence | SATISFIED |
| `P01-VER-007` | ADR-0004 | Correct protocol mistakes by introducing a new wire version. | P01 | Version-change governance test | P01 evidence | SATISFIED |
| `P01-VER-008` | ADR-0004 | Retain version 1 decoding for its documented support window. | P01 | Compatibility-window tests | P01 evidence | SATISFIED |
| `P01-BOUND-006` | ADR-0004 | Keep core values and traits transport-independent. | P01 | Core dependency and public API audit | P01 evidence | SATISFIED |

## P02 source requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P02-SRC-001` | Steering P02 | Find candidates for lexicon and morphology. | P02 | Discovery dossiers | P02 evidence | SATISFIED |
| `P02-SRC-002` | Steering P02 | Find candidates for contextual POS evaluation. | P02 | Discovery dossiers | P02 evidence | SATISFIED |
| `P02-SRC-003` | Steering P02 | Find candidates for PT-BR intents and multi-intent evaluation. | P02 | Discovery dossiers | P02 evidence | SATISFIED |
| `P02-SRC-004` | Steering P02 | Find ASR-noise data only when required. | P02 | Need/evidence decision | P02 evidence | SATISFIED |
| `P02-SRC-009` | Steering P02 | Find an independently licensed PT-BR frequency source or prototype a measured corpus-free substitute. | P02 | Discovery dossier or fallback benchmark | P02 evidence | SATISFIED |
| `P02-SRC-005` | Steering P02 | Read complete licenses before admission. | P02 | License-text hashes | P02 evidence | SATISFIED |
| `P02-SRC-006` | Steering P02 | Keep all acquisitions quarantined until admission. | P02 | Tree/build isolation test | P02 evidence | SATISFIED |
| `P02-SRC-007` | Steering P02 | Prototype a measured corpus-free fallback for every missing essential source. | P02 | Prototype benchmark | P02 evidence | SATISFIED |
| `P02-SRC-008` | Steering P02 | Freeze anti-leakage splits before import. | P02 | Split manifest timestamp/hash | P02 evidence | SATISFIED |

## P03 data-pipeline requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P03-PIPE-001` | Steering P03 | Make source fetch opt-in. | P03 | Offline normal-build test | P03 evidence | SATISFIED |
| `P03-PIPE-002` | Steering P03 | Verify source bytes before import. | P03 | Hash corruption test | P03 evidence | SATISFIED |
| `P03-PIPE-003` | Steering P03 | Validate license and schema before import. | P03 | Negative manifest tests | P03 evidence | SATISFIED |
| `P03-PIPE-004` | Steering P03 | Normalize through a deterministic versioned transform. | P03 | Replay/hash test | P03 evidence | SATISFIED |
| `P03-PIPE-005` | Steering P03 | Apply the frozen anti-leakage split. | P03 | Split reproducibility test | P03 evidence | SATISFIED |
| `P03-PIPE-006` | Steering P03 | Compile byte-stable data independent of input order. | P03 | Permutation/hash test | P03 evidence | SATISFIED |
| `P03-PIPE-007` | Steering P03 | Remove a source and all derivatives by source ID. | P03 | Selective-removal test | P03 evidence | SATISFIED |
| `P03-PIPE-008` | Steering P03 | Produce identical hashes in two clean builds. | P03 | Two-directory comparison | P03 evidence | SATISFIED |
| `P03-COMP-001` | Steering P03 | Implement the `nlu-data`/`xtask` data-pipeline component. | P03 | Workspace component and invocation tests | P03 evidence | SATISFIED |
| `P03-MAN-001` | Steering P03 | Implement versioned data-pipeline manifests. | P03 | Manifest schema and round-trip tests | P03 evidence | SATISFIED |
| `P03-CMD-001` | Steering P03 | Provide the opt-in `fetch` command. | P03 | CLI contract and offline-default tests | P03 evidence | SATISFIED |
| `P03-CMD-002` | Steering P03 | Provide the `verify` command. | P03 | CLI contract and hash-corruption tests | P03 evidence | SATISFIED |
| `P03-CMD-003` | Steering P03 | Provide the `import` command. | P03 | CLI contract and admission-gate tests | P03 evidence | SATISFIED |
| `P03-CMD-004` | Steering P03 | Provide the `normalize` command. | P03 | CLI contract and deterministic replay tests | P03 evidence | SATISFIED |
| `P03-CMD-005` | Steering P03 | Provide the `validate` command. | P03 | CLI contract and invalid-input tests | P03 evidence | SATISFIED |
| `P03-CMD-006` | Steering P03 | Provide the `split` command. | P03 | CLI contract and split-replay tests | P03 evidence | SATISFIED |
| `P03-CMD-007` | Steering P03 | Provide the `compile` command. | P03 | CLI contract and byte-stability tests | P03 evidence | SATISFIED |

## P04 Unicode requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P04-UNI-001` | Steering P04 | Preserve original bytes. | P04 | Property tests | P04 evidence | SATISFIED |
| `P04-UNI-002` | Steering P04 | Make normalization idempotent. | P04 | Property tests | P04 evidence | SATISFIED |
| `P04-UNI-003` | Steering P04 | Map normalized spans reversibly to original spans. | P04 | Round-trip properties | P04 evidence | SATISFIED |
| `P04-UNI-004` | Steering P04 | Reject offsets outside UTF-8 boundaries. | P04 | Fuzz/negative tests | P04 evidence | SATISFIED |
| `P04-UNI-005` | Steering P04 | Handle combining code points explicitly. | P04 | Public-source regressions | P04 evidence | SATISFIED |
| `P04-UNI-006` | Steering P04 | Handle control code points under explicit policy. | P04 | Adversarial tests | P04 evidence | SATISFIED |
| `P04-UNI-007` | Steering P04 | Enforce the input byte limit. | P04 | Byte-limit tests | P04 evidence | SATISFIED |
| `P04-UNI-008` | Steering P04 | Enforce the Unicode scalar-value limit. | P04 | Scalar-limit tests | P04 evidence | SATISFIED |
| `P04-UNI-009` | Steering P04 | Enforce the grapheme-cluster limit. | P04 | Grapheme-limit tests | P04 evidence | SATISFIED |
| `P04-UNI-010` | Steering P04 | Enforce the token-count limit. | P04 | Token-limit tests | P04 evidence | SATISFIED |
| `P04-UNI-011` | Steering P04 | Handle zero-width code points under explicit policy. | P04 | Adversarial tests | P04 evidence | SATISFIED |
| `P04-UNI-012` | Steering P04 | Handle Unicode confusables under explicit policy. | P04 | Adversarial tests | P04 evidence | SATISFIED |
| `P04-UNI-013` | Steering P04 | Cover every relevant Unicode equivalence under an explicit normalization policy. | P04 | Public-source equivalence regressions | P04 evidence | SATISFIED |

## P05 tokenization requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P05-TOK-001` | Steering P05 | Trace every token to original bytes. | P05 | Span properties | P05 evidence | SATISFIED |
| `P05-TOK-002` | Steering P05 | Explain every split and merge. | P05 | Decision provenance test | P05 evidence | SATISFIED |
| `P05-TOK-003` | Steering P05 | Tokenize punctuation only from admitted evidence. | P05 | Public-source punctuation regressions | P05 evidence | SATISFIED |
| `P05-TOK-004` | Steering P05 | Tokenize numeric forms only from admitted evidence. | P05 | Public-source numeric regressions | P05 evidence | SATISFIED |
| `P05-TOK-005` | Steering P05 | Tokenize time forms only from admitted evidence. | P05 | Public-source time regressions | P05 evidence | SATISFIED |
| `P05-TOK-006` | Steering P05 | Tokenize unit forms only from admitted evidence. | P05 | Public-source unit regressions | P05 evidence | SATISFIED |
| `P05-TOK-007` | Steering P05 | Tokenize contractions only from admitted evidence. | P05 | Public-source contraction regressions | P05 evidence | SATISFIED |
| `P05-TOK-008` | Steering P05 | Tokenize clitics only from admitted evidence. | P05 | Public-source clitic regressions | P05 evidence | SATISFIED |
| `P05-TOK-009` | Steering P05 | Tokenize abbreviations only from admitted evidence. | P05 | Public-source abbreviation regressions | P05 evidence | SATISFIED |
| `P05-TOK-010` | Steering P05 | Tokenize multiunit expressions only from admitted evidence. | P05 | Public-source multiunit regressions | P05 evidence | SATISFIED |
| `P05-TOK-011` | Steering P05 | Preserve unsupported forms explicitly. | P05 | Unknown-form tests | P05 evidence | SATISFIED |
| `P05-TOK-012` | Steering P05 | Make tokenization deterministic. | P05 | Repetition and permutation properties | P05 evidence | SATISFIED |
| `P05-TOK-013` | Steering P05 | Make tokenization idempotent. | P05 | Re-tokenization fixed-point properties | P05 evidence | SATISFIED |

## P06 lexicon requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P06-LEX-001` | Steering P06 | Import only admitted sources. | P06 | Admission gate test | P06 evidence | SATISFIED |
| `P06-LEX-002` | Steering P06 | Attach a source ID to every lexical entry. | P06 | Full-entry audit | P06 evidence | SATISFIED |
| `P06-LEX-003` | Steering P06 | Make source conflicts observable. | P06 | Conflict fixture | P06 evidence | SATISFIED |
| `P06-LEX-004` | Steering P06 | Build read-only runtime indexes. | P06 | Mutation/type tests | P06 evidence | SATISFIED |
| `P06-LEX-005` | Steering P06 | Produce byte-stable lexicon artifacts. | P06 | Two-build hash test | P06 evidence | SATISFIED |
| `P06-LEX-006` | Steering P06 | Remove every lexical contribution of a removed source. | P06 | Removal audit | P06 evidence | SATISFIED |
| `P06-LEX-007` | Steering P06 | Use pure transformations when importing lexical sources. | P06 | Purity and deterministic replay tests | P06 evidence | SATISFIED |
| `P06-LEX-008` | AGENTS.md, SOURCE-POLICY.md | Attach ordered immutable transformation lineage and derivative-license identity to every imported lexical entry. | P06 | Full-entry lineage and license audit | P06 evidence | SATISFIED |

## P07 morphology requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P07-MOR-001` | Steering P07 | Return all source-justified analyses. | P07 | Ambiguity evaluation | P07 evidence | SATISFIED |
| `P07-MOR-002` | Steering P07 | Separate lexical evidence from inference. | P07 | Provenance assertions | P07 evidence | SATISFIED |
| `P07-MOR-003` | Steering P07 | Never invent an unknown lemma. | P07 | Unknown negatives | P07 evidence | SATISFIED |
| `P07-MOR-004` | Steering P07 | Never invent unknown morphological features. | P07 | Unknown negatives | P07 evidence | SATISFIED |
| `P07-MOR-005` | Steering P07 | Version the evaluation dataset and split. | P07 | Manifest check | P07 evidence | SATISFIED |
| `P07-MOR-006` | Steering P07 | Reproduce metrics and confusion matrix. | P07 | Runner replay | P07 evidence | SATISFIED |
| `P07-MOR-007` | Steering P07 | Evaluate morphology in an isolated evaluation harness. | P07 | Evaluation-input isolation audit | P07 evidence | SATISFIED |
| `P07-MOR-008` | Steering P07 | Produce a reproducible morphology error analysis. | P07 | Versioned error-analysis replay | P07 evidence | SATISFIED |

## P08 contextual POS requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P08-POS-001` | Steering P08 | Implement a simple documented baseline. | P08 | Baseline tests | P08 evidence | SATISFIED |
| `P08-POS-002` | Steering P08 | Compare the selected local deterministic approach against baseline. | P08 | Frozen evaluation | P08 evidence | SATISFIED |
| `P08-POS-003` | Steering P08 | Fix training seed and configuration. | P08 | Artifact rebuild | P08 evidence | SATISFIED |
| `P08-POS-004` | Steering P08 | Split evaluation by sentence, document, and origin. | P08 | Leakage audit | P08 evidence | SATISFIED |
| `P08-POS-005` | Steering P08 | Keep runtime artifacts lightweight and offline. | P08 | Package/network test | P08 evidence | SATISFIED |
| `P08-POS-006` | Steering P08 | Evaluate unknowns and preserved ambiguity. | P08 | Error analysis | P08 evidence | SATISFIED |

## P09 intent requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P09-INT-001` | Steering P09 | Version the intent schema. | P09 | Schema version tests | P09 evidence | SATISFIED |
| `P09-INT-002` | Steering P09 | Use stable intent identifiers. | P09 | Intent-ID stability tests | P09 evidence | SATISFIED |
| `P09-INT-003` | Steering P09 | Validate typed slot constraints. | P09 | Schema negatives | P09 evidence | SATISFIED |
| `P09-INT-004` | Steering P09 | Attach span evidence to recognized slots. | P09 | Evidence assertions | P09 evidence | SATISFIED |
| `P09-INT-005` | Steering P09 | Rank hypotheses deterministically. | P09 | Permutation tests | P09 evidence | SATISFIED |
| `P09-INT-006` | Steering P09 | Clarify hypotheses inside the ambiguity margin. | P09 | Tie/margin tests | P09 evidence | SATISFIED |
| `P09-INT-007` | Steering P09 | Abstain when no hypothesis satisfies evidence thresholds. | P09 | Negative suite | P09 evidence | SATISFIED |
| `P09-INT-008` | Steering P09 | Produce canonical intent output independent of insertion order. | P09 | Byte/property tests | P09 evidence | SATISFIED |
| `P09-INT-009` | Steering P09 | Use stable slot identifiers. | P09 | Slot-ID stability tests | P09 evidence | SATISFIED |
| `P09-INT-010` | Steering P09 | Reject an invalid intent schema before interpretation begins. | P09 | Early schema-rejection tests | P09 evidence | SATISFIED |
| `P09-EVAL-001` | Steering P09 | Reproduce exact-semantic metrics for every intent stratum. | P09 | Versioned evaluation runner | P09 evidence | SATISFIED |
| `P09-EVAL-002` | Steering P09 | Reproduce exact-value metrics for every slot stratum. | P09 | Versioned evaluation runner | P09 evidence | SATISFIED |

## P10 Home Assistant catalog requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P10-HA-001` | Steering P10 | Pin and document the official HA contract baseline. | P10 | Source/tag evidence | P10 evidence | SATISFIED |
| `P10-HA-002` | Steering P10 | Build immutable catalog snapshots. | P10 | Mutation/reload tests | P10 evidence | SATISFIED |
| `P10-HA-003` | Steering P10 | Preserve entity stable IDs. | P10 | Entity snapshot contract tests | P10 evidence | SATISFIED |
| `P10-HA-004` | Steering P10 | Preserve alias provenance. | P10 | Alias audit | P10 evidence | SATISFIED |
| `P10-HA-005` | Steering P10 | Reject stale snapshot generations. | P10 | Stale tests | P10 evidence | SATISFIED |
| `P10-HA-006` | Steering P10 | Resolve ties through clarification. | P10 | Collision tests | P10 evidence | SATISFIED |
| `P10-HA-007` | User | Emit an explicit capability disposition for every pinned built-in domain. | P10 | Coverage report validator | P10 evidence | SATISFIED |
| `P10-HA-008` | Steering 6.4 | Keep sanitized fixtures free of residential data. | P10 | Fixture privacy scan | P10 evidence | SATISFIED |
| `P10-HA-009` | Steering P10 | Explain every entity-ranking factor with source evidence. | P10 | Ranking explanation snapshots | P10 evidence | SATISFIED |
| `P10-HA-010` | Steering P10 | Never select an entity by display name alone. | P10 | Display-name collision tests | P10 evidence | SATISFIED |
| `P10-HA-011` | Steering P10 | Never break an entity tie by insertion position. | P10 | Catalog permutation tests | P10 evidence | SATISFIED |
| `P10-HA-012` | Steering P10 | Publish catalog reloads atomically without exposing mixed generations. | P10 | Concurrent generation-swap tests | P10 evidence | SATISFIED |
| `P10-HA-013` | Steering P10 | Preserve device stable IDs. | P10 | Device snapshot contract tests | P10 evidence | SATISFIED |
| `P10-HA-014` | Steering P10 | Preserve area stable IDs. | P10 | Area snapshot contract tests | P10 evidence | SATISFIED |
| `P10-HA-015` | Steering P10 | Preserve floor stable IDs. | P10 | Floor snapshot contract tests | P10 evidence | SATISFIED |
| `P10-HA-016` | Steering P10 | Preserve domain stable IDs. | P10 | Domain snapshot contract tests | P10 evidence | SATISFIED |
| `P10-HA-017` | Steering P10 | Preserve typed catalog capabilities. | P10 | Capability snapshot contract tests | P10 evidence | SATISFIED |
| `P10-HA-018` | Steering P10 | Attack alias collisions without selecting an arbitrary target. | P10 | Alias-collision reproducers | P10 evidence | SATISFIED |
| `P10-HA-019` | ADR-0007 | Rebuild catalog snapshots from Home Assistant. | P10, P14 | Restart and source-of-truth tests | P14 evidence | PENDING |
| `P10-HA-020` | ADR-0007 | Do not persist catalog snapshots by default. | P10, P14 | Filesystem and backup canary tests | P14 evidence | PENDING |
| `P10-HA-021` | ADR-0002 | Keep entity resolution extensible across Home Assistant domains. | P10 | Unknown-domain and descriptor-extension tests | P10 evidence | SATISFIED |
| `P10-HA-022` | ADR-0002 | Keep state-query planning extensible across Home Assistant domains. | P10 | Cross-domain state-query contract tests | P10 evidence | SATISFIED |
| `P10-HA-023` | ADR-0002 | Treat official built-in Home Assistant intent families as minimum release coverage. | P10, P15 | Pinned intent-family coverage audit | P15 evidence | PENDING |
| `P10-HA-024` | ADR-0002 | Enable additional actionable domains only through reviewed capability descriptors, never arbitrary service-name paths. | P10, P13 | Descriptor-admission and arbitrary-service negatives | P13 evidence | PENDING |
| `P10-HA-025` | ADR-0002 | Define a machine-readable release coverage report indexed by domain, operation, and capability. | P10, P15 | Coverage-report schema and completeness test | P15 evidence | PENDING |
| `P10-HA-026` | ADR-0002 | Preserve each entity's Home Assistant domain association in every catalog snapshot. | P10 | Entity-snapshot association tests | P10 evidence | SATISFIED |
| `P10-HA-027` | ADR-0002 | Preserve each entity's typed capability associations in every catalog snapshot. | P10 | Entity-snapshot association tests | P10 evidence | SATISFIED |
| `P10-HA-028` | ADR-0002 | Preserve each entity's area association in every catalog snapshot. | P10 | Entity-snapshot association tests | P10 evidence | SATISFIED |
| `P10-HA-029` | ADR-0002 | Preserve each entity's floor association in every catalog snapshot. | P10 | Entity-snapshot association tests | P10 evidence | SATISFIED |
| `P10-HA-030` | ADR-0002 | Preserve each entity's device association in every catalog snapshot. | P10 | Entity-snapshot association tests | P10 evidence | SATISFIED |
| `P10-HA-031` | ADR-0002 | Preserve each entity's alias associations in every catalog snapshot. | P10 | Entity-alias association audit | P10 evidence | SATISFIED |
| `P10-HA-032` | ADR-0002 | Bind every entity record to its catalog snapshot generation. | P10 | Missing and stale-generation tests | P10 evidence | SATISFIED |
| `P10-ACT-001` | ADR-0002 | Require an explicit typed operation schema before admitting an actionable capability. | P10-P14 | Descriptor-admission negative tests | P14 evidence | PENDING |
| `P10-ACT-002` | ADR-0002 | Require an explicit capability check before admitting an action path. | P10-P14 | Missing-capability-check negatives | P14 evidence | PENDING |
| `P10-ACT-003` | ADR-0002 | Require an explicit risk-policy mapping before admitting an action path. | P10-P14 | Missing-policy-map negatives | P14 evidence | PENDING |
| `P10-ACT-004` | ADR-0002 | Require an explicit adapter mapping before admitting an action path. | P10-P14 | Missing-adapter-map negatives | P14 evidence | PENDING |
| `P10-ROLL-001` | ADR-0002 | Allow a capability descriptor to be disabled without changing core types. | P10-P15 | Descriptor-disable compatibility test | P15 evidence | PENDING |
| `P10-ROLL-002` | ADR-0002 | Allow a capability descriptor to be narrowed without changing core types. | P10-P15 | Descriptor-narrowing compatibility test | P15 evidence | PENDING |

## P11 multi-intent requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P11-MULTI-001` | Steering P11 | Build graph nodes from explicit clause evidence. | P11 | Span/graph tests | P11 evidence | SATISFIED |
| `P11-MULTI-002` | Steering P11 | Represent ordering relations explicitly. | P11 | Ordered graph tests | P11 evidence | SATISFIED |
| `P11-MULTI-003` | Steering P11 | Represent negation scope explicitly. | P11 | Negation tests | P11 evidence | SATISFIED |
| `P11-MULTI-004` | Steering P11 | Reject unsupported argument propagation. | P11 | Sharing negatives | P11 evidence | SATISFIED |
| `P11-MULTI-005` | Steering P11 | Prevent contradictory graphs from producing executable plans. | P11 | Conflict tests | P11 evidence | SATISFIED |
| `P11-MULTI-006` | Steering P11 | Mark safe-partial semantics explicitly. | P11 | Partial policy tests | P11 evidence | SATISFIED |
| `P11-MULTI-007` | Steering P11 | Serialize graphs canonically. | P11 | Byte snapshots | P11 evidence | SATISFIED |
| `P11-MULTI-008` | Steering P11 | Measure exact graph match on admitted gold data. | P11 | Evaluation runner | P11 evidence | SATISFIED |
| `P11-MULTI-009` | Steering P11 | Never split clauses solely because a connective token is present. | P11 | Connective counterexamples | P11 evidence | SATISFIED |
| `P11-MULTI-010` | ADR-0007 | Classify every executable graph as partial-safe, atomic-only, or non-executable before adapter routing. | P11 | Graph-policy contract tests | P11 evidence | SATISFIED |
| `P11-MULTI-011` | Steering P11 | Represent supported argument sharing explicitly. | P11 | Positive sharing tests | P11 evidence | SATISFIED |
| `P11-MULTI-012` | Steering P11 | Cover coordination in admitted multi-intent gold data. | P11 | Gold-stratum coverage audit | P11 evidence | SATISFIED |
| `P11-MULTI-013` | Steering P11 | Cover scope in admitted multi-intent gold data. | P11 | Gold-stratum coverage audit | P11 evidence | SATISFIED |
| `P11-MULTI-014` | Steering P11 | Cover negation in admitted multi-intent gold data. | P11 | Gold-stratum coverage audit | P11 evidence | SATISFIED |
| `P11-MULTI-015` | Steering P11 | Cover conflict in admitted multi-intent gold data. | P11 | Gold-stratum coverage audit | P11 evidence | SATISFIED |

## P12 session requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P12-SES-001` | Steering P12 | Use opaque session identifiers. | P12 | Format/privacy tests | P12 evidence | SATISFIED |
| `P12-SES-002` | Steering P12 | Expire session state through injected logical time. | P12 | TTL tests | P12 evidence | SATISFIED |
| `P12-SES-003` | Steering P12 | Bound pending clarification options. | P12 | Resource tests | P12 evidence | SATISFIED |
| `P12-SES-004` | Steering P12 | Bind pending options to stable capability IDs. | P12 | Confused-deputy tests | P12 evidence | SATISFIED |
| `P12-SES-005` | Steering P12 | Consume one-time continuation state once. | P12 | Replay tests | P12 evidence | SATISFIED |
| `P12-SES-006` | Steering P12 | Invalidate pending state after catalog generation changes. | P12 | Stale tests | P12 evidence | SATISFIED |
| `P12-SES-007` | Steering P12 | Complete only the requested missing slot. | P12 | Slot-isolation tests | P12 evidence | SATISFIED |
| `P12-SES-008` | Steering P12 | Isolate concurrent sessions. | P12 | Race/model tests | P12 evidence | SATISFIED |
| `P12-SES-009` | Steering P12 | Support explicit cancellation. | P12 | Cancellation tests | P12 evidence | SATISFIED |
| `P12-SES-010` | Steering P12 | Purge terminal session state. | P12 | Purge tests | P12 evidence | SATISFIED |
| `P12-SES-011` | Steering P12 | Verify result origin and capability identity before using a result in continuation state. | P12 | Forged-origin and confused-deputy tests | P12 evidence | SATISFIED |
| `P12-SES-012` | Steering P12 | Bound pending referent state. | P12 | Resource tests | P12 evidence | SATISFIED |
| `P12-SES-013` | Steering P12 | Represent every pending referent as a closed typed stable identifier. | P12 | Type and hostile-decode tests | P12 evidence | SATISFIED |
| `P12-SES-014` | Steering P12 | Prevent one session from completing another session's pending state. | P12 | Cross-session completion tests | P12 evidence | SATISFIED |
| `P12-SES-015` | Steering P12 | Prevent an unresolved tie from completing a plan. | P12 | Unresolved-tie tests | P12 evidence | SATISFIED |
| `P12-SES-016` | ADR-0007 | Keep session state only in process memory. | P12-P14 | Restart and filesystem canary tests | P14 evidence | PENDING |
| `P12-COMPAT-001` | ADR-0007 | Run the Wyoming conversation-bridge contract test before freezing transport behavior. | P12-P13 | Freeze-order and contract-test evidence | P13 evidence | PENDING |
| `P12-COMPAT-002` | ADR-0007 | Verify whether Wyoming preserves the complete clarification outcome. | P12-P13 | Clarification round-trip test | P13 evidence | PENDING |
| `P12-COMPAT-003` | ADR-0007 | Verify whether Wyoming preserves the ordered-execution contract. | P12-P13 | Ordered-graph round-trip test | P13 evidence | PENDING |
| `P12-COMPAT-004` | ADR-0007 | Verify whether Wyoming preserves caller-authorization context. | P12-P13 | Caller-context round-trip test | P13 evidence | PENDING |
| `P12-COMPAT-005` | ADR-0007 | Verify whether Wyoming preserves an explicit continuation flag. | P12-P13 | Continuation round-trip test | P13 evidence | PENDING |
| `P12-COMPAT-006` | ADR-0007 | Require the companion path whenever Wyoming would lose clarification, ordering, authorization, or continuation semantics. | P12-P14 | Per-semantic transport-selection tests | P14 evidence | PENDING |
| `P12-SES-017` | ADR-0007 | Bind continuation state to the originating Home Assistant caller. | P12-P14 | Cross-user continuation tests | P14 evidence | PENDING |
| `P12-SES-018` | ADR-0007 | Bind session state to the active pairing epoch. | P12-P14 | Old-epoch session tests | P14 evidence | PENDING |
| `P12-SES-019` | ADR-0007 | Invalidate affected sessions when either paired peer restarts. | P12-P14 | Peer-restart session tests | P14 evidence | PENDING |
| `P12-SES-020` | ADR-0007 | Reject stale-session continuation before execution. | P12-P14 | Stale-session rejection tests | P14 evidence | PENDING |

## P13 policy and server requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P13-POL-001` | Steering P13 | Classify operation risk. | P13 | Policy matrix tests | P13 evidence | PENDING |
| `P13-POL-002` | Steering P13 | Deny actions absent an explicit allow rule. | P13 | Exhaustive default tests | P13 evidence | PENDING |
| `P13-POL-003` | Steering P13 | Bind confirmation to plan, session, and capability. | P13 | Tamper/replay tests | P13 evidence | PENDING |
| `P13-POL-004` | Steering 6.3 | Prevent a denied plan from becoming any partial execution. | P13 | No-effect denial tests | P13 evidence | PENDING |
| `P13-PROTO-001` | Steering P13 | Enforce final DTO byte/depth/count limits. | P13 | Hostile parser tests | P13 evidence | PENDING |
| `P13-PROTO-002` | Steering P13 | Reject unknown protocol versions. | P13 | Version negatives | P13 evidence | PENDING |
| `P13-PROTO-003` | ADR-0004 | Introduce a new protocol version for an incompatible wire change. | P13 | Incompatible-change governance test | P13 evidence | PENDING |
| `P13-PROTO-004` | ADR-0004 | Retain protocol version 1 decoding for its documented support window. | P13 | Compatibility-window tests | P13 evidence | PENDING |
| `P13-PROTO-005` | ADR-0007 | Expose every complete typed outcome through the versioned local protocol. | P13 | Outcome-variant round-trip tests | P13 evidence | PENDING |
| `P13-PROTO-006` | ADR-0007 | Expose bounded typed diagnostics through the versioned local protocol. | P13 | Diagnostic schema, redaction, and limit tests | P13 evidence | PENDING |
| `P13-SRV-001` | Steering P13 | Bind only documented local listeners. | P13 | Socket inspection | P13 evidence | PENDING |
| `P13-SRV-002` | Steering P13 | Prevent server outbound network connections. | P13 | Network sandbox test | P13 evidence | PENDING |
| `P13-SRV-003` | Steering P13 | Keep credentials out of the server environment. | P13 | Environment sentinel tests | P13 evidence | PENDING |
| `P13-SRV-004` | Steering P13 | Reload immutable state atomically. | P13 | Concurrent reload tests | P13 evidence | PENDING |
| `P13-SRV-005` | Steering P13 | Expose bounded health without sensitive data. | P13 | Health response tests | P13 evidence | PENDING |
| `P13-SRV-006` | Steering P13 | Keep credentials out of server memory. | P13 | Process-memory sentinel tests | P13 evidence | PENDING |
| `P13-AUTH-001` | ADR-0007 | Provision the companion pairing credential only through an explicit local Home Assistant config flow and add-on ingress pairing UI. | P13-P14 | Pairing lifecycle tests | P14 evidence | PENDING |
| `P13-AUTH-002` | ADR-0007, ADR-0019, USR-018 | Keep persistent pairing credentials and private session keys only in dedicated process-wide-locked companion-peer and add-on adapter memory, with only bounded one-time provisioning copies. | P13-P14 | Memory-lock, transient-copy, file, backup, dump, swap, and startup-failure tests | P14 evidence | PENDING |
| `P13-AUTH-003` | ADR-0007 | Mutually authenticate and encrypt every companion-channel connection with an admitted FOSS transport. | P13-P14 | Active peer-substitution tests | P14 evidence | PENDING |
| `P13-AUTH-004` | ADR-0007 | Authenticate the add-on endpoint instead of trusting network location. | P13-P14 | Server-impersonation tests | P14 evidence | PENDING |
| `P13-AUTH-005` | ADR-0007 | Authenticate the complete companion-channel handshake transcript. | P13-P14 | Transcript-substitution tests | P14 evidence | PENDING |
| `P13-AUTH-006` | ADR-0007 | Rotate or revoke pairing credentials without accepting two execution epochs. | P13-P14 | Interrupted-rotation and revocation tests | P14 evidence | PENDING |
| `P13-AUTH-007` | ADR-0007 | Invalidate old connections, continuations, and confirmations when a pairing epoch changes. | P13-P14 | Stale-epoch state tests | P14 evidence | PENDING |
| `P13-AUTH-008` | ADR-0007 | Bind every companion request to protocol version, key epoch, direction, connection nonce, and monotonic sequence. | P13-P14 | Replay, reflection, and version tests | P14 evidence | PENDING |
| `P13-AUTH-009` | ADR-0007 | Bind every companion request to stable operation ID, node-attempt ID, and plan digest. | P13-P14 | Operation-identity substitution tests | P14 evidence | PENDING |
| `P13-AUTH-010` | ADR-0007 | Bind every companion request to session, capability, catalog generation, context ID, and caller ID. | P13-P14 | Field-by-field substitution tests | P14 evidence | PENDING |
| `P13-AUTH-011` | ADR-0007 | Destroy the active pairing epoch and require local re-pairing after either peer restarts. | P13-P14 | Peer-restart lifecycle tests | P14 evidence | PENDING |
| `P13-AUTH-012` | ADR-0007 | Prevent backup restore from reactivating a pairing credential, connection, or epoch. | P13-P15 | Backup restore credential tests | P15 evidence | PENDING |
| `P13-PAIR-001` | ADR-0007 | Use a distinct locally generated credential for companion pairing. | P13-P14 | Credential-origin and identity tests | P14 evidence | PENDING |
| `P13-PAIR-002` | ADR-0007 | Generate the pairing credential with the host CSPRNG. | P13-P14 | Entropy-source substitution and source audit | P14 evidence | PENDING |
| `P13-PAIR-003` | ADR-0007 | Display the pairing credential exactly once. | P13-P14 | Config-flow replay and redisplay negatives | P14 evidence | PENDING |
| `P13-PAIR-004` | ADR-0007 | Store only non-secret endpoint and peer metadata in the Home Assistant config entry. | P13-P14 | Config-entry and backup inspection | P14 evidence | PENDING |
| `P13-PAIR-005` | ADR-0007 | Prevent the companion channel from using or receiving the Supervisor token. | P13-P14 | Token sentinel tests on both peers | P14 evidence | PENDING |
| `P13-PAIR-006` | ADR-0007 | Prevent a pending pairing credential from authorizing execution. | P13-P14 | Pending-rotation execution negative | P14 evidence | PENDING |
| `P13-PAIR-007` | ADR-0007 | Perform credential rotation only as an explicit local re-pair transaction. | P13-P14 | Remote and implicit rotation negatives | P14 evidence | PENDING |
| `P13-PAIR-008` | ADR-0007 | Leave at most the previously active in-memory epoch usable after interrupted rotation. | P13-P14 | Interrupted-rotation schedule tests | P14 evidence | PENDING |
| `P13-PAIR-009` | ADR-0007 | Revoke the companion channel when either paired peer restarts. | P13-P14 | Peer-restart channel tests | P14 evidence | PENDING |
| `P13-PAIR-010` | ADR-0007 | Revoke the companion channel when either config entry is removed. | P13-P14 | Config-entry removal tests | P14 evidence | PENDING |
| `P13-PAIR-011` | ADR-0007 | Destroy the active pairing epoch when either paired peer is removed. | P13-P14 | Peer-removal epoch tests | P14 evidence | PENDING |
| `P13-PAIR-012` | ADR-0007 | Require explicit local re-pairing after either paired peer is removed. | P13-P14 | Peer-removal re-pairing tests | P14 evidence | PENDING |
| `P13-CHAN-001` | ADR-0007 | Require both companion-channel peers to prove possession of the pairing credential. | P13-P14 | One-sided-possession negatives | P14 evidence | PENDING |
| `P13-CHAN-002` | ADR-0007 | Reject duplicate authenticated messages before execution. | P13-P14 | Duplicate-message replay test | P14 evidence | PENDING |
| `P13-CHAN-003` | ADR-0007 | Reject out-of-window authenticated messages before execution. | P13-P14 | Sequence-window boundary tests | P14 evidence | PENDING |
| `P13-CHAN-004` | ADR-0007 | Reject wrong-direction authenticated messages before execution. | P13-P14 | Reflection tests | P14 evidence | PENDING |
| `P13-CHAN-005` | ADR-0007 | Reject cross-connection authenticated messages before execution. | P13-P14 | Connection-substitution tests | P14 evidence | PENDING |
| `P13-CHAN-006` | ADR-0007 | Reject field-substituted authenticated messages before execution. | P13-P14 | Field-by-field substitution tests | P14 evidence | PENDING |
| `P13-CHAN-007` | ADR-0007 | Reject old-epoch authenticated messages before execution. | P13-P14 | Epoch replay tests | P14 evidence | PENDING |
| `P13-BIND-001` | ADR-0007 | Invalidate every old operation ID when a new pairing epoch activates. | P13-P14 | Cross-epoch operation-ID tests | P14 evidence | PENDING |
| `P13-GATE-001` | Steering P13 | Pass retained hostile protocol fuzz and exhaustion checks. | P13 | Fuzz corpus and command evidence | P13 evidence | PENDING |

## P14 adapter and response requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P14-HA-001` | Steering P14 | Revalidate every incoming plan. | P14 | Plan tamper tests | P14 evidence | PENDING |
| `P14-HA-002` | Steering P14 | Keep the Supervisor token only in the adapter process. | P14 | Child-environment sentinel test | P14 evidence | PENDING |
| `P14-HA-003` | Steering P14 | Use bounded typed local IPC between server and adapter. | P14 | IPC parser/permission tests | P14 evidence | PENDING |
| `P14-HA-004` | Steering P14 | Allocate one stable operation ID before first dispatch and preserve it across reconnect retries. | P14 | Cross-connection identity tests | P14 evidence | PENDING |
| `P14-HA-005` | Steering P14 | Stop partial-safe ordered execution after the first failure or indeterminate result. | P14 | Sequential multi-intent tests | P14 evidence | PENDING |
| `P14-HA-006` | ADR-0007 | Use Wyoming multi-intent only for unordered safe-partial graphs. | P14 | HA concurrency contract tests | P14 evidence | PENDING |
| `P14-HA-007` | ADR-0007 | Use the companion integration for ordered or full clarification outcomes. | P14 | End-to-end conversation tests | P14 evidence | PENDING |
| `P14-HA-008` | Steering P14 | Test against a faithful deterministic mock. | P14 | Mock e2e suite | P14 evidence | PENDING |
| `P14-HA-009` | ADR-0007 | Test against ephemeral HA 2026.8.3. | P14 | Real integration suite | P14 evidence | PENDING |
| `P14-HA-010` | ADR-0007 | Test against latest stable HA at build time. | P14 | Real integration suite | P14 evidence | PENDING |
| `P14-HA-011` | Steering P14 | Bound every Home Assistant operation by an explicit timeout. | P14 | Timeout boundary tests | P14 evidence | PENDING |
| `P14-HA-012` | ADR-0007 | Treat a timed-out operation as indeterminate and never retry it blindly. | P14 | Late-completion and duplicate-effect tests | P14 evidence | PENDING |
| `P14-HA-013` | ADR-0007 | Restrict Wyoming execution to proven single-target non-user-scoped safe handlers. | P14 | Pinned handler-contract tests | P14 evidence | PENDING |
| `P14-HA-014` | ADR-0007 | Route multi-target, sensitive, ordered, and caller-authorized operations through the companion integration. | P14 | Transport-selection tests | P14 evidence | PENDING |
| `P14-HA-015` | ADR-0007 | Preserve and bind Home Assistant caller context through companion authorization and execution. | P14 | Cross-user and missing-context tests | P14 evidence | PENDING |
| `P14-HA-016` | ADR-0007 | Run add-on adapter and server under distinct unprivileged identities. | P14 | UID, environment, and procfs isolation tests | P14 evidence | PENDING |
| `P14-HA-017` | ADR-0007 | Use companion sequential execution only for graphs whose partial completion is explicitly safe. | P14 | Mid-graph failure tests | P14 evidence | PENDING |
| `P14-HA-018` | ADR-0007 | Abstain before any external effect for transactional or unsafe-partial graphs without a reviewed single-operation atomic capability. | P14 | No-first-effect atomicity tests | P14 evidence | PENDING |
| `P14-HA-019` | ADR-0007 | Require kernel peer-credential checks on every add-on adapter/server IPC connection. | P14 | Wrong-peer IPC tests | P14 evidence | PENDING |
| `P14-HA-020` | Steering P14 | Revalidate the bound catalog snapshot generation before every operation. | P14 | Stale-generation tests | P14 evidence | PENDING |
| `P14-CONTRACT-001` | ADR-0007 | Pin the Home Assistant custom-component loader contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-002` | ADR-0007 | Pin the Home Assistant config-flow contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-003` | ADR-0007 | Pin the Home Assistant config-entry contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-004` | ADR-0007 | Pin the Home Assistant auth-manager contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-005` | ADR-0007 | Pin the Home Assistant permission contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-006` | ADR-0007 | Pin the Home Assistant service-dispatch contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-007` | ADR-0007 | Pin the Home Assistant backup-restore contract. | P14 | Source-path, revision, and contract tests | P14 evidence | PENDING |
| `P14-CONTRACT-008` | User, ADR-0007 | Demonstrate at least one reviewed capability that maps an entire multi-node graph to one pinned Home Assistant operation and prove that every contract-defined failure point either rejects before the first external effect or leaves all requested effects applied. | P14 | Pinned source-contract audit and exhaustive failure-point zero-or-all effect matrix | P14 evidence | PENDING |
| `P14-HA-022` | ADR-0007 | Revalidate every plan constraint independently at the execution boundary. | P14 | One-field tamper matrix | P14 evidence | PENDING |
| `P14-HA-023` | ADR-0007 | Resolve the current Home Assistant user and require the user to remain active immediately before every effect. | P14 | Missing, inactive, and revoked-user tests | P14 evidence | PENDING |
| `P14-HA-024` | ADR-0007 | Check the pinned operation-specific Home Assistant permission for every expanded target immediately before every effect. | P14 | Unauthorized and target-expansion tests | P14 evidence | PENDING |
| `P14-HA-025` | ADR-0007 | Require current admin status for every capability mapped to an admin-only Home Assistant operation. | P14 | Admin-revocation tests | P14 evidence | PENDING |
| `P14-HA-026` | ADR-0007 | Deny execution when a capability lacks a complete pinned Home Assistant permission mapping. | P14 | Missing-permission-map tests | P14 evidence | PENDING |
| `P14-HA-027` | ADR-0007 | Restrict Supervisor-token API calls to a pinned read-only catalog and capability synchronization allowlist. | P14 | Deny-by-default API mock | P14 evidence | PENDING |
| `P14-HA-028` | ADR-0007 | Prohibit the add-on adapter from calling Home Assistant services. | P14 | Static call graph and service-endpoint tests | P14 evidence | PENDING |
| `P14-HA-029` | ADR-0007 | Reserve an operation and node-attempt identity before its first external effect. | P14 | Reserve-before-effect schedule tests | P14 evidence | PENDING |
| `P14-HA-030` | ADR-0007 | Return the cached typed result for a completed duplicate without issuing another effect. | P14 | Lost-response duplicate tests | P14 evidence | PENDING |
| `P14-HA-031` | ADR-0007 | Return `Indeterminate` for an in-flight duplicate until explicit Home Assistant state reconciliation. | P14 | In-flight reconnect tests | P14 evidence | PENDING |
| `P14-HA-032` | ADR-0007 | Reject expired or unknown old operation IDs instead of treating them as new work. | P14 | Expiry and unknown-ID tests | P14 evidence | PENDING |
| `P14-HA-033` | ADR-0007 | Keep the in-memory operation-result ledger for at least the maximum session and retry lifetime. | P14 | Logical-time retention tests | P14 evidence | PENDING |
| `P14-HA-034` | ADR-0007 | Invalidate old operation IDs and require reconciliation after peer restart and re-pair. | P14 | Restart and re-pair retry tests | P14 evidence | PENDING |
| `P14-HA-037` | ADR-0007 | Prohibit the add-on adapter from firing Home Assistant events. | P14 | Static call graph and event-endpoint tests | P14 evidence | PENDING |
| `P14-HA-038` | ADR-0007 | Prohibit the add-on adapter from processing Home Assistant conversations. | P14 | Static call graph and conversation-endpoint tests | P14 evidence | PENDING |
| `P14-HA-039` | ADR-0007 | Prohibit the add-on adapter from writing Home Assistant state. | P14 | Static call graph and state-write tests | P14 evidence | PENDING |
| `P14-HA-040` | ADR-0007 | Prohibit the add-on adapter from writing Home Assistant configuration. | P14 | Static call graph and configuration-write tests | P14 evidence | PENDING |
| `P14-HA-041` | ADR-0007 | Prohibit the add-on adapter from using any other effect-producing Home Assistant endpoint. | P14 | Deny-by-default endpoint mock | P14 evidence | PENDING |
| `P14-WYO-001` | ADR-0007 | Advertise only an installed PT-BR Wyoming `IntentProgram`. | P14 | Wyoming discovery contract test | P14 evidence | PENDING |
| `P14-WYO-002` | ADR-0007 | Map abstention to Wyoming `NotRecognized`. | P14 | Wyoming abstention test | P14 evidence | PENDING |
| `P14-WYO-003` | ADR-0007 | Do not advertise a Wyoming `HandleProgram`. | P14 | Wyoming discovery negative test | P14 evidence | PENDING |
| `P14-GATE-001` | Steering P14, ADR-0007 | Run the P14 gate without production credentials while retaining mandatory ephemeral Home Assistant 2026.8.3 and latest-stable integration tests. | P14 | Credential canaries plus both real-HA suites | P14 evidence | PENDING |
| `P14-RESP-001` | Steering P14 | Render interpretation and execution results separately. | P14 | Response snapshots | P14 evidence | PENDING |
| `P14-PRIV-001` | ADR-0007 | Prevent credential values from entering logs. | P14 | Credential log canary | P14 evidence | PENDING |
| `P14-PRIV-002` | ADR-0007 | Prevent credential values from entering files or backups. | P14 | Credential filesystem and backup canary | P14 evidence | PENDING |
| `P14-PRIV-003` | ADR-0007 | Prevent credential values from entering errors. | P14 | Credential error canary | P14 evidence | PENDING |
| `P14-PRIV-004` | ADR-0007 | Prevent credential values from entering metrics. | P14 | Credential metric canary | P14 evidence | PENDING |
| `P14-PRIV-005` | ADR-0007 | Prevent credential values from entering diagnostics. | P14 | Credential diagnostic canary | P14 evidence | PENDING |
| `P14-PRIV-006` | ADR-0007 | Prevent credential values from entering crash output. | P14 | Credential crash canary | P14 evidence | PENDING |
| `P14-PRIV-007` | User | Prevent residential values from entering logs. | P14 | Residential log canary | P14 evidence | PENDING |
| `P14-PRIV-008` | User | Prevent residential values from entering files. | P14 | Residential filesystem canary | P14 evidence | PENDING |
| `P14-PRIV-009` | User | Prevent residential values from entering errors. | P14 | Residential error canary | P14 evidence | PENDING |
| `P14-PRIV-010` | User | Prevent residential values from entering metrics. | P14 | Residential metric canary | P14 evidence | PENDING |
| `P14-PRIV-011` | User | Prevent residential values from entering diagnostics. | P14 | Residential diagnostic canary | P14 evidence | PENDING |
| `P14-PRIV-012` | User | Prevent residential values from entering crash output. | P14 | Residential crash canary | P14 evidence | PENDING |
| `P14-PRIV-013` | ADR-0007 | Keep utterances only in process memory. | P14 | Restart and filesystem canary tests | P14 evidence | PENDING |
| `P14-PRIV-014` | ADR-0007 | Bound utterance retention by an explicit TTL. | P14 | Logical-time retention test | P14 evidence | PENDING |
| `P14-HA-035` | ADR-0002 | Produce clarification or abstention for an unknown Home Assistant service instead of a generic call. | P14 | Exact clarification-or-abstention outcome plus no-effect test | P14 evidence | PENDING |
| `P14-HA-036` | ADR-0002 | Produce clarification or abstention for a stale operation schema instead of a generic call. | P14 | Exact clarification-or-abstention outcome plus no-effect test | P14 evidence | PENDING |
| `P14-HA-042` | ADR-0002 | Produce only clarification or abstention for an unknown Home Assistant domain, never dispatch a generic call, and cause no external effect. | P14 | Exact outcome-variant plus zero-dispatch and no-effect test | P14 evidence | PENDING |
| `P14-HA-043` | ADR-0002 | Produce only clarification or abstention for an unknown Home Assistant capability, never dispatch a generic call, and cause no external effect. | P14 | Exact outcome-variant plus zero-dispatch and no-effect test | P14 evidence | PENDING |
| `P14-WYO-004` | ADR-0007 | Expose a bounded local Wyoming 1.10-compatible recognition service. | P14 | Wyoming 1.10 compatibility and limit tests | P14 evidence | PENDING |
| `P14-WYO-005` | ADR-0007 | Map a recognized plan to a Wyoming intent only after adapter revalidation. | P14 | Revalidation-order test | P14 evidence | PENDING |
| `P14-WYO-006` | ADR-0007 | Treat area, floor, group, wildcard, and other expanding targets as non-single-target. | P14 | Expanding-target classification tests | P14 evidence | PENDING |
| `P14-WYO-007` | ADR-0007 | Limit the initial Wyoming-safe handler set to reviewed read-only handlers. | P14 | Handler-allowlist audit | P14 evidence | PENDING |
| `P14-WYO-008` | ADR-0007 | Route every non-Wyoming-safe recognized plan to the companion or abstain. | P14 | Exhaustive transport-selection test | P14 evidence | PENDING |
| `P14-WYO-009` | ADR-0007 | Prevent raw Home Assistant service names from crossing either adapter boundary. | P14 | Raw-service-name parser negatives | P14 evidence | PENDING |
| `P14-WYO-010` | ADR-0007 | Prevent unvalidated Home Assistant payloads from crossing either adapter boundary. | P14 | Payload-smuggling tests | P14 evidence | PENDING |
| `P14-WYO-011` | ADR-0007 | Limit zero-companion Wyoming use to recognition and safe-read compatibility. | P14 | Zero-companion capability tests | P14 evidence | PENDING |
| `P14-WYO-012` | ADR-0007 | Require every Wyoming-safe handler contract to prove that the operation is non-sensitive. | P14 | Sensitive-handler allowlist negatives | P14 evidence | PENDING |
| `P14-WYO-013` | ADR-0007 | Require every Wyoming-safe handler contract to prove safety under the handler's actual timeout semantics. | P14 | Pinned timeout-contract tests | P14 evidence | PENDING |
| `P14-WYO-014` | ADR-0007 | Require every Wyoming-safe handler contract to prove safety under the handler's actual partial-success semantics. | P14 | Pinned partial-success contract tests | P14 evidence | PENDING |
| `P14-EXEC-001` | ADR-0007 | Require every Wyoming multi-intent node to independently pass the handler allowlist. | P14 | Per-node allowlist mutation tests | P14 evidence | PENDING |
| `P14-EXEC-002` | ADR-0007 | Require a Wyoming multi-intent graph to prove that all nodes are independent. | P14 | Dependency-edge transport tests | P14 evidence | PENDING |
| `P14-EXEC-003` | ADR-0007 | Prohibit dependent graphs from Wyoming execution. | P14 | Dependent-graph no-effect test | P14 evidence | PENDING |
| `P14-EXEC-004` | ADR-0007 | Prohibit conflicting graphs from Wyoming execution. | P14 | Conflict transport test | P14 evidence | PENDING |
| `P14-EXEC-005` | ADR-0007 | Revalidate each sequential companion node against all prior results. | P14 | Prior-result substitution tests | P14 evidence | PENDING |
| `P14-EXEC-006` | ADR-0007 | Do not treat sequential stopping as atomic execution. | P14 | Mid-graph effect test | P14 evidence | PENDING |
| `P14-EXEC-007` | ADR-0007 | Do not treat best-effort rollback as atomic execution. | P14 | Rollback-failure test | P14 evidence | PENDING |
| `P14-EXEC-008` | ADR-0007 | Do not treat compensation as atomic execution. | P14 | Compensation-failure test | P14 evidence | PENDING |
| `P14-EXEC-009` | ADR-0007 | Always abstain on a conflicting graph. | P14 | Conflict abstention test | P14 evidence | PENDING |
| `P14-EXEC-010` | ADR-0007 | Always abstain on a contradictory graph. | P14 | Contradiction abstention test | P14 evidence | PENDING |
| `P14-EXEC-011` | ADR-0007 | Abstain when a required atomic capability is stale. | P14 | Stale-atomic-capability test | P14 evidence | PENDING |
| `P14-EXEC-012` | ADR-0007 | Abstain when a required atomic capability is unavailable. | P14 | Unavailable-atomic-capability test | P14 evidence | PENDING |
| `P14-AUTH-001` | ADR-0007 | Accept caller identity only from `ConversationInput.context` received inside Home Assistant. | P14 | Untrusted-identity injection tests | P14 evidence | PENDING |
| `P14-AUTH-002` | ADR-0007 | Expand the exact target set immediately before every external operation. | P14 | Late target-expansion tests | P14 evidence | PENDING |
| `P14-AUTH-003` | ADR-0007 | Require current `POLICY_CONTROL` permission for every entity operation target. | P14 | Per-target permission tests | P14 evidence | PENDING |
| `P14-AUTH-004` | ADR-0007 | Repeat authorization after every prior graph result. | P14 | Mid-graph authorization schedule tests | P14 evidence | PENDING |
| `P14-AUTH-005` | ADR-0007 | Stop before the next effect when caller authorization is revoked between graph nodes. | P14 | Mid-graph revocation test | P14 evidence | PENDING |
| `P14-AUTH-006` | ADR-0007 | Stop before the next effect when the target set expands between graph nodes. | P14 | Mid-graph target-expansion test | P14 evidence | PENDING |
| `P14-AUTH-007` | ADR-0007 | Deny system contexts unless a reviewed capability permits that exact Home Assistant-originated context. | P14 | System-context allowlist tests | P14 evidence | PENDING |
| `P14-IPC-001` | ADR-0007 | Use a Unix-domain socket for add-on adapter/server IPC. | P14 | Socket-family inspection | P14 evidence | PENDING |
| `P14-IPC-002` | ADR-0007 | Place the IPC socket in a dedicated directory. | P14 | Filesystem-layout test | P14 evidence | PENDING |
| `P14-IPC-003` | ADR-0007 | Set the IPC socket mode to exactly `0660`. | P14 | Socket-mode test | P14 evidence | PENDING |
| `P14-IPC-004` | ADR-0007 | Restrict the IPC socket group to the adapter and server service identities. | P14 | Group-membership and foreign-peer tests | P14 evidence | PENDING |
| `P14-PROC-001` | ADR-0007 | Make the add-on adapter the only project process able to initiate Supervisor or Home Assistant API connections. | P14 | Process-specific network policy tests | P14 evidence | PENDING |
| `P14-PROC-002` | ADR-0007 | Remove both Home Assistant credentials from the NLU server environment. | P14 | Dual-credential environment canaries | P14 evidence | PENDING |
| `P14-PROC-003` | ADR-0007 | Use the add-on adapter as the container entry process. | P14 | Process-tree inspection | P14 evidence | PENDING |
| `P14-PROC-004` | ADR-0007 | Remove the injected Supervisor token from inherited state before starting the server. | P14 | Startup-order and environment tests | P14 evidence | PENDING |
| `P14-PROC-005` | ADR-0007 | Drop adapter privileges before accepting traffic. | P14 | Startup race and effective-UID tests | P14 evidence | PENDING |
| `P14-PROC-006` | ADR-0007 | Prevent the server from reading adapter environment through procfs. | P14 | Procfs environment access test | P14 evidence | PENDING |
| `P14-PROC-007` | ADR-0007 | Prevent the server from reading adapter memory through procfs. | P14 | Procfs memory access test | P14 evidence | PENDING |
| `P14-ADAPT-001` | ADR-0007 | Allow the add-on adapter to relay authenticated typed requests to the companion. | P14 | Typed-relay contract tests | P14 evidence | PENDING |
| `P14-ADAPT-002` | ADR-0007 | Prevent the add-on adapter from executing relayed operations. | P14 | Relay no-effect test | P14 evidence | PENDING |
| `P14-ADAPT-003` | ADR-0007 | Make the companion the only project component that executes Home Assistant operations. | P14 | Execution call-graph audit | P14 evidence | PENDING |
| `P14-ADAPT-004` | ADR-0007 | Require the companion to execute through Home Assistant internal typed APIs. | P14 | API call-contract test | P14 evidence | PENDING |
| `P14-IDEM-001` | ADR-0007 | Bound the in-memory operation-result ledger. | P14 | Capacity and eviction tests | P14 evidence | PENDING |
| `P14-IDEM-002` | ADR-0007 | Never redispatch an in-flight operation blindly after response loss. | P14 | Lost-response duplicate-effect test | P14 evidence | PENDING |
| `P14-IDEM-003` | ADR-0007 | Invalidate affected sessions when a peer restart destroys the pairing epoch. | P14 | Restart/session invalidation test | P14 evidence | PENDING |
| `P14-IDEM-004` | ADR-0007 | Return typed `Indeterminate` when cancellation cannot prove that Home Assistant stopped an effect. | P14 | Cancellation race test | P14 evidence | PENDING |
| `P14-IDEM-005` | ADR-0007 | Delay retry after timeout or cancellation until idempotency state or explicit reconciliation proves the outcome. | P14 | Retry-gating tests | P14 evidence | PENDING |
| `P14-PRIV-015` | ADR-0007 | Prevent credentials from entering command arguments. | P14 | Process-argument credential canary | P14 evidence | PENDING |
| `P14-PRIV-016` | ADR-0007 | Prevent credentials from entering core DTOs. | P14 | DTO credential canary | P14 evidence | PENDING |
| `P14-PRIV-017` | ADR-0007 | Prevent credentials from entering the server environment. | P14 | Server-environment credential canary | P14 evidence | PENDING |
| `P14-PRIV-018` | ADR-0007 | Prevent credentials from being inherited by server child workers. | P14 | Worker-environment credential canary | P14 evidence | PENDING |
| `P14-PRIV-019` | ADR-0007 | Prevent utterance transcript text from being exported as telemetry. | P14 | Transcript telemetry canary and network-denied test | P14 evidence | PENDING |
| `P14-PRIV-020` | ADR-0007 | Prevent residential values from entering the NLU server environment. | P14 | Server-environment residential canary | P14 evidence | PENDING |
| `P14-PRIV-021` | ADR-0007 | Prevent residential values from entering the core process environment. | P14 | Core-environment residential canary | P14 evidence | PENDING |
| `P14-PRIV-022` | ADR-0007 | Limit residential values in protocol DTOs to schema-authorized fields required for the current bounded request or typed outcome. | P14 | Allowed-field round-trip and unrelated-field rejection tests | P14 evidence | PENDING |
| `P14-PRIV-023` | ADR-0007 | Limit residential values in core DTOs to schema-authorized fields required for the current bounded request or typed outcome. | P14 | Allowed-field round-trip and unrelated-field rejection tests | P14 evidence | PENDING |
| `P14-ROLL-001` | ADR-0002 | Keep Home Assistant transport replaceable behind the adapter boundary. | P14-P15 | Alternate-transport contract test | P15 evidence | PENDING |
| `P14-ROLL-002` | ADR-0007 | Permit Wyoming discovery to be disabled while retaining the versioned local recognition API. | P14-P15 | Wyoming-disabled recognition test | P15 evidence | PENDING |
| `P14-ROLL-003` | ADR-0007 | Permit companion execution to be disabled while retaining the versioned local recognition API. | P14-P15 | Companion-disabled recognition test | P15 evidence | PENDING |

## P15 evaluation and package requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P15-EVAL-001` | Steering P15 | Report intent exact match. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-002` | Steering P15 | Report slot exact match. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-003` | Steering P15 | Report entity exact match. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-004` | Steering P15 | Report graph exact match. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-005` | Steering P15 | Report clarification metrics. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-006` | Steering P15 | Report abstention metrics. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-007` | Steering P15 | Report false-plan rate separately. | P15 | Evaluation runner | P15 evidence | PENDING |
| `P15-EVAL-008` | Steering P15 | Report clean-text results as a separate stratum. | P15 | Dataset and report manifest check | P15 evidence | PENDING |
| `P15-EVAL-009` | Steering P15 | Report ASR-noise results as a separate stratum. | P15 | Dataset and report manifest check | P15 evidence | PENDING |
| `P15-EVAL-010` | Steering P15 | Report negative-suite results as a separate stratum. | P15 | Dataset and report manifest check | P15 evidence | PENDING |
| `P15-EVAL-011` | Steering 6.1, P15 | Version every evaluation metric result. | P15 | Metric-report schema | P15 evidence | PENDING |
| `P15-EVAL-012` | Steering 6.1, P15 | Prove final evaluation isolation and absence of known leakage. | P15 | Access and split chronology audit | P15 evidence | PENDING |
| `P15-PERF-001` | Steering P15 | Retain raw timing and resource samples. | P15 | Artifact validation | P15 evidence | PENDING |
| `P15-GATE-001` | Steering P15 | Trace every release threshold to a requirement or recorded comparison baseline. | P15 | Threshold provenance test | P15 evidence | PENDING |
| `P15-PKG-001` | Steering P15 | Build byte-reproducible per-architecture add-on artifacts. | P15 | Two-build digest test | P15 evidence | PENDING |
| `P15-PKG-002` | Steering P15 | Generate an SBOM. | P15 | SBOM schema/content check | P15 evidence | PENDING |
| `P15-PKG-003` | Steering P15 | Generate complete license and attribution notices. | P15 | Path/license audit | P15 evidence | PENDING |
| `P15-PKG-004` | Steering P15 | Publish checksums for release artifacts. | P15 | Checksum verification | P15 evidence | PENDING |
| `P15-PKG-005` | Steering P15 | Verify clean installation. | P15 | Install test | P15 evidence | PENDING |
| `P15-PKG-006` | Steering P15 | Verify supported upgrade. | P15 | Upgrade test | P15 evidence | PENDING |
| `P15-PKG-007` | Steering P15 | Verify rollback without sensitive-data leakage. | P15 | Rollback/privacy test | P15 evidence | PENDING |
| `P15-PKG-008` | ADR-0007 | Declare Wyoming discovery in the add-on manifest. | P15 | Add-on manifest contract test | P15 evidence | PENDING |
| `P15-PKG-009` | ADR-0007 | Declare Home Assistant API access in the add-on manifest. | P15 | Add-on manifest contract test | P15 evidence | PENDING |
| `P15-PKG-010` | ADR-0007 | Package the companion as an open-source custom integration beside the add-on. | P15 | Distribution and clean-install test | P15 evidence | PENDING |
| `P15-PKG-011` | ADR-0001 | Generate a complete source-hash inventory for every release input. | P15 | Release-input identity and hash audit | P15 evidence | PENDING |
| `P15-ARCH-001` | ADR-0007 | Support the Home Assistant add-on on `amd64`. | P15 | Native package and install test | P15 evidence | PENDING |
| `P15-ARCH-002` | ADR-0007 | Support the Home Assistant add-on on `aarch64`. | P15 | Native package and install test | P15 evidence | PENDING |
| `P15-LIFE-001` | ADR-0007 | Install the add-on and companion integration together into a clean supported Home Assistant instance. | P15 | Clean dual-deliverable installation test | P15 evidence | PENDING |
| `P15-LIFE-002` | ADR-0007 | Prove complete removal of both deliverables. | P15 | Removal and residue scan | P15 evidence | PENDING |
| `P15-LIFE-003` | ADR-0007 | Prove supported upgrade of both deliverables. | P15 | Dual-deliverable upgrade test | P15 evidence | PENDING |
| `P15-LIFE-004` | ADR-0007 | Prove restart invalidates the prior epoch and supports explicit local re-pairing. | P15 | Restart and re-pair lifecycle test | P15 evidence | PENDING |
| `P15-LIFE-005` | ADR-0007 | Prove rollback behavior for both deliverables. | P15 | Dual-deliverable rollback test | P15 evidence | PENDING |
| `P15-COV-001` | ADR-0002 | Report release coverage for every pinned Home Assistant domain. | P15 | Domain-denominator completeness test | P15 evidence | PENDING |
| `P15-COV-002` | ADR-0002 | Report release coverage for every reviewed typed operation. | P15 | Operation-denominator completeness test | P15 evidence | PENDING |
| `P15-COV-003` | ADR-0002 | Report release coverage for every reviewed capability. | P15 | Capability-denominator completeness test | P15 evidence | PENDING |
| `P15-COV-004` | ADR-0002 | Distinguish catalog coverage from actionable coverage in release reports. | P15 | Coverage-report semantic test | P15 evidence | PENDING |
| `P15-LIC-001` | ADR-0007 | Include the companion integration source under an OSI-approved license in the release. | P15 | Package source/license audit | P15 evidence | PENDING |
| `P15-LIC-002` | ADR-0007 | Preserve all required Wyoming implementation license and attribution notices. | P15 | Dependency-to-notice audit | P15 evidence | PENDING |
| `P15-ARCH-003` | ADR-0007 | Add a new architecture only after reproducible native packaging and clean installation pass for that architecture. | P15 | Architecture-admission gate test | P15 evidence | PENDING |
| `P15-ROLL-001` | ADR-0002 | Keep Home Assistant packaging replaceable behind the adapter boundary. | P15 | Alternate-package installation contract test | P15 evidence | PENDING |

## P16 red-team requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `P16-RED-001` | Steering P16 | Attack Unicode handling. | P16 | Unicode reproducers | P16 evidence | PENDING |
| `P16-RED-002` | Steering P16 | Attack protocol parsers. | P16 | Parser reproducers | P16 evidence | PENDING |
| `P16-RED-003` | Steering P16 | Attack negation handling. | P16 | Negation reproducers | P16 evidence | PENDING |
| `P16-RED-004` | Steering P16 | Attack stale catalog handling. | P16 | Stale-catalog reproducers | P16 evidence | PENDING |
| `P16-RED-005` | Steering P16 | Attack replay handling. | P16 | Replay reproducers | P16 evidence | PENDING |
| `P16-RED-006` | Steering P16 | Attack source leakage. | P16 | Source-leakage reproducers | P16 evidence | PENDING |
| `P16-RED-007` | Steering P16 | Attack locale-dependent behavior. | P16 | Locale reproducers | P16 evidence | PENDING |
| `P16-RED-008` | Steering P16 | Attack secret handling. | P16 | Secret canaries and reproducers | P16 evidence | PENDING |
| `P16-RED-009` | Steering P16 | Attack add-on installation. | P16 | Installation reproducers | P16 evidence | PENDING |
| `P16-RED-010` | Steering P16 | Remediate every true P0, P1, and P2 with a regression. | P16 | Finding ledger | P16 evidence | PENDING |
| `P16-RED-011` | Steering P16 | Attack command injection boundaries. | P16 | Command-injection reproducers | P16 evidence | PENDING |
| `P16-RED-012` | Steering P16 | Attack source substitution. | P16 | Source-substitution reproducers | P16 evidence | PENDING |
| `P16-RED-013` | Steering P16 | Audit and attack every Rust `unsafe` block. | P16 | Unsafe inventory and reproducers | P16 evidence | PENDING |
| `P16-RED-014` | Steering P16 | Attack Unicode confusables. | P16 | Confusable reproducers | P16 evidence | PENDING |
| `P16-RED-015` | Steering P16 | Attack input limits. | P16 | Limit reproducers | P16 evidence | PENDING |
| `P16-RED-016` | Steering P16 | Attack protocol framing. | P16 | Framing reproducers | P16 evidence | PENDING |
| `P16-RED-017` | Steering P16 | Attack parser exhaustion. | P16 | Exhaustion reproducers | P16 evidence | PENDING |
| `P16-RED-018` | Steering P16 | Attack coordination handling. | P16 | Coordination reproducers | P16 evidence | PENDING |
| `P16-RED-019` | Steering P16 | Attack contradiction handling. | P16 | Contradiction reproducers | P16 evidence | PENDING |
| `P16-RED-020` | Steering P16 | Attack alias collisions. | P16 | Collision reproducers | P16 evidence | PENDING |
| `P16-RED-021` | Steering P16 | Attack plan tampering. | P16 | Tampering reproducers | P16 evidence | PENDING |
| `P16-RED-022` | Steering P16 | Attack concurrency behavior. | P16 | Concurrency reproducers | P16 evidence | PENDING |
| `P16-RED-023` | Steering P16 | Attack confirmation behavior. | P16 | Confirmation reproducers | P16 evidence | PENDING |
| `P16-RED-024` | Steering P16 | Attack retry behavior. | P16 | Retry reproducers | P16 evidence | PENDING |
| `P16-RED-025` | Steering P16 | Attack partial-execution behavior. | P16 | Partial-effect reproducers | P16 evidence | PENDING |
| `P16-RED-026` | Steering P16 | Attack license removal. | P16 | License-removal reproducers | P16 evidence | PENDING |
| `P16-RED-027` | Steering P16 | Attack timezone-dependent behavior. | P16 | Timezone reproducers | P16 evidence | PENDING |
| `P16-RED-028` | Steering P16 | Attack path-dependent behavior. | P16 | Path reproducers | P16 evidence | PENDING |
| `P16-RED-029` | Steering P16 | Attack build reproducibility. | P16 | Clean-build reproducers | P16 evidence | PENDING |
| `P16-RED-030` | Steering P16 | Attack residential-data handling. | P16 | Residential-data canaries | P16 evidence | PENDING |
| `P16-RED-031` | Steering P16 | Attack add-on upgrade. | P16 | Upgrade reproducers | P16 evidence | PENDING |
| `P16-RED-032` | Steering P16 | Attack add-on rollback. | P16 | Rollback reproducers | P16 evidence | PENDING |
| `P16-RED-033` | Steering P16 | Attack template injection boundaries. | P16 | Template-injection reproducers | P16 evidence | PENDING |
| `P16-RED-034` | Steering P16 | Attack protocol injection boundaries. | P16 | Protocol-injection reproducers | P16 evidence | PENDING |
| `P16-RED-035` | Steering P16 | Attack structured-data injection boundaries. | P16 | Structured-data reproducers | P16 evidence | PENDING |
| `P16-RED-036` | Steering P16 | Attack dependency substitution. | P16 | Dependency-substitution reproducers | P16 evidence | PENDING |
| `P16-RED-037` | Steering P16 | Attack toolchain substitution. | P16 | Toolchain-substitution reproducers | P16 evidence | PENDING |
| `P16-RED-038` | Steering P16 | Attack package substitution. | P16 | Package-substitution reproducers | P16 evidence | PENDING |
| `P16-RED-039` | Steering P16 | Audit and attack every unsafe dependency boundary. | P16 | Unsafe-dependency inventory and reproducers | P16 evidence | PENDING |
| `P16-GATE-001` | Steering P16 | Freeze the P16 candidate before red-team attacks. | P16 | Git chronology audit | P16 evidence | PENDING |
| `P16-GATE-002` | Steering P16 | Retain reproducible red-team attacks and baselines. | P16 | Reproducer replay | P16 evidence | PENDING |
| `P16-GATE-003` | Steering P16 | Justify every red-team severity. | P16 | Finding severity audit | P16 evidence | PENDING |
| `P16-GATE-004` | Steering P16 | Pass every common suite after P16 remediation. | P16 | Common-suite command evidence | P16 evidence | PENDING |
| `P16-GATE-005` | Steering P16 | Pass every adversarial suite after P16 remediation. | P16 | Adversarial-suite command evidence | P16 evidence | PENDING |
| `P16-GATE-006` | Steering P16 | Obtain every applicable reviewer PASS on one P16 candidate. | P16 | Reviewer baseline equality | P16 evidence | PENDING |
| `P16-GATE-007` | Steering P16 | Complete and retain the frozen-candidate attacks before beginning remediation. | P16 | Attack and remediation Git chronology audit | P16 evidence | PENDING |

## Final release requirements

| ID | Source | Requirement | Owner | Verification | Evidence | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `FINAL-REV-001` | Steering 14 | Obtain final requirements PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-REV-002` | Steering 14 | Obtain final architecture PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-REV-003` | Steering 14 | Obtain final linguistics/data PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-REV-004` | Steering 14 | Obtain final security/protocol PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-REV-005` | Steering 14 | Obtain final session/concurrency PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-REV-006` | Steering 14 | Obtain final HA integration PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-REV-007` | Steering 14 | Obtain final reproducibility/operations PASS. | FINAL | Reviewer report | Final evidence | PENDING |
| `FINAL-SCOPE-001` | Steering 14 | Require final-requirements to audit complete requirement-to-code-to-test traceability. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-SCOPE-002` | Steering 14 | Require final-architecture to audit boundaries, coupling, invariants, and ADRs. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-SCOPE-003` | Steering 14 | Require final-linguistics-data to audit PT-BR, coverage, provenance, license, and leakage. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-SCOPE-004` | Steering 14 | Require final-security-protocol to audit parsers, policy, plans, tampering, and resources. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-SCOPE-005` | Steering 14 | Require final-session-concurrency to audit TTL, replay, races, isolation, and capabilities. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-SCOPE-006` | Steering 14 | Require final-ha-integration to audit mocks, idempotency, staleness, confirmation, and partial execution. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-SCOPE-007` | Steering 14 | Require final-repro-operations to audit builds, determinism, SBOM, packages, upgrade, and rollback. | FINAL | Final reviewer scope schema | Final evidence | PENDING |
| `FINAL-INDEP-001` | Steering 14 | Run at least seven final review agents. | FINAL | Final reviewer-count audit | Final evidence | PENDING |
| `FINAL-INDEP-002` | Steering 14 | Keep every final reviewer read-only. | FINAL | Final reviewer change audit | Final evidence | PENDING |
| `FINAL-INDEP-003` | Steering 14 | Prevent final reviewers from sharing conclusions before their verdicts. | FINAL | Final reviewer process declaration | Final evidence | PENDING |
| `FINAL-ADV-001` | Steering 14 | Require every final reviewer to try to disprove release readiness. | FINAL | Counterexample-attempt field audit | Final evidence | PENDING |
| `FINAL-CHAIR-001` | Steering 14 | Obtain release-chair PASS on the same candidate. | FINAL | Chair report | Final evidence | PENDING |
| `FINAL-CHAIR-002` | Steering 14 | Prohibit the release chair from deciding by vote. | FINAL | Chair-method schema | Final evidence | PENDING |
| `FINAL-CHAIR-003` | Steering 14 | Require the release chair to audit evidence sufficiency. | FINAL | Chair evidence audit | Final evidence | PENDING |
| `FINAL-CHAIR-004` | Steering 14 | Require the release chair to reproduce a critical sample from every final track. | FINAL | Chair command replay | Final evidence | PENDING |
| `FINAL-CHAIR-005` | Steering 14 | Require the release chair to identify cross-track contradictions. | FINAL | Chair contradiction field audit | Final evidence | PENDING |
| `FINAL-LOOP-001` | Steering 14 | Consolidate final findings without deleting dissent. | FINAL | Final finding-ledger audit | Final evidence | PENDING |
| `FINAL-LOOP-002` | Steering 14 | Reproduce every final P0, P1, and P2. | FINAL | Final finding reproducers | Final evidence | PENDING |
| `FINAL-LOOP-003` | Steering 14 | Reproduce a documented sample of final P3 findings. | FINAL | P3 sample audit | Final evidence | PENDING |
| `FINAL-LOOP-004` | Steering 14 | Add a regression for every true final finding. | FINAL | Final finding-to-test trace | Final evidence | PENDING |
| `FINAL-LOOP-005` | Steering 14 | Freeze a new baseline after every final remediation. | FINAL | Git chronology audit | Final evidence | PENDING |
| `FINAL-LOOP-006` | Steering 14 | Rerun every final track affected by remediation. | FINAL | Final rerun matrix | Final evidence | PENDING |
| `FINAL-LOOP-007` | Steering 14 | Rerun the global suite after final remediation. | FINAL | Global-suite command evidence | Final evidence | PENDING |
| `FINAL-LOOP-008` | Steering 14 | Rerun the release chair after final remediation. | FINAL | Chair baseline audit | Final evidence | PENDING |
| `FINAL-LOOP-009` | Steering 14 | Require all seven final reviewers and the release chair to pass one baseline. | FINAL | Eight-report baseline equality | Final evidence | PENDING |
| `FINAL-RISK-001` | Steering 14 | Close every P0, P1, and P2 before release. | FINAL | Finding ledger | Final evidence | PENDING |
| `FINAL-RDY-001` | Steering 14 | Require every mapped requirement to be satisfied. | FINAL | Requirement-status gate | Final evidence | PENDING |
| `FINAL-RDY-002` | Steering 14 | Require P00 through P16 to pass in verifiable history. | FINAL | Phase-checkpoint ancestry audit | Final evidence | PENDING |
| `FINAL-RDY-003` | Steering 14 | Reproduce critical builds and tests from a clean environment. | FINAL | Clean-clone command replay | Final evidence | PENDING |
| `FINAL-RDY-004` | Steering 14 | Require a local deterministic runtime. | FINAL | Runtime determinism gate | Final evidence | PENDING |
| `FINAL-RDY-005` | Steering 14 | Require core and server to have no external execution authority or credentials. | FINAL | Process and call-graph audit | Final evidence | PENDING |
| `FINAL-RDY-006` | Steering 14 | Require traceable compatible data and dependencies. | FINAL | Provenance and license gate | Final evidence | PENDING |
| `FINAL-RDY-007` | Steering 14 | Require evaluations with no known leakage. | FINAL | Evaluation isolation audit | Final evidence | PENDING |
| `FINAL-RDY-008` | Steering 14 | Require every residual P3 to have no correctness, security, operational, or license impact. | FINAL | Residual-risk gate | Final evidence | PENDING |
| `FINAL-RDY-009` | Steering 14 | Require measured resource limits. | FINAL | Resource report validation | Final evidence | PENDING |
| `FINAL-RDY-010` | Steering 14 | Require a verified SBOM. | FINAL | SBOM schema and path audit | Final evidence | PENDING |
| `FINAL-RDY-011` | Steering 14 | Require verified release checksums. | FINAL | Checksum audit | Final evidence | PENDING |
| `FINAL-RDY-012` | Steering 14 | Require seven final reviewers and the release chair to pass the same baseline. | FINAL | Final report baseline equality | Final evidence | PENDING |
| `FINAL-RDY-013` | Steering 14 | Require the final report to correspond exactly to the delivered tree. | FINAL | Report-to-tree correspondence audit | Final evidence | PENDING |
| `FINAL-RDY-014` | Steering 14 | Require verified installation. | FINAL | Clean-install audit | Final evidence | PENDING |
| `FINAL-RDY-015` | Steering 14 | Require verified upgrade. | FINAL | Upgrade audit | Final evidence | PENDING |
| `FINAL-RDY-016` | Steering 14 | Require verified rollback. | FINAL | Rollback audit | Final evidence | PENDING |
| `FINAL-ART-001` | Steering 15.1 | Emit `docs/phases/FINAL-REPORT.md`. | FINAL | Exact path and report-schema audit | Final evidence | PENDING |
| `FINAL-ART-002` | Steering 15.1 | Emit final `docs/evidence/REQUIREMENTS-TRACEABILITY.md`. | FINAL | Final traceability completeness audit | Final evidence | PENDING |
| `FINAL-ART-003` | Steering 15.1 | Emit `docs/evidence/FINAL-VALIDATION.md`. | FINAL | Exact path and validation audit | Final evidence | PENDING |
| `FINAL-ART-004` | Steering 15.1 | Emit `docs/evidence/RESIDUAL-RISKS.md`. | FINAL | Exact path and risk-schema audit | Final evidence | PENDING |
| `FINAL-ART-005` | Steering 15.1 | Emit `docs/evidence/REPRODUCTION.md`. | FINAL | Exact path and command replay | Final evidence | PENDING |
| `FINAL-ART-006` | Steering 15.1 | Emit checksums for every release artifact. | FINAL | Checksum coverage and verification | Final evidence | PENDING |
| `FINAL-ART-007` | Steering 15.1 | Emit the release SBOM. | FINAL | SBOM path and content audit | Final evidence | PENDING |
| `FINAL-ART-008` | Steering 15.1 | Emit clean installation instructions. | FINAL | Instruction replay | Final evidence | PENDING |
| `FINAL-ART-009` | Steering 15.1 | Emit rollback instructions. | FINAL | Rollback instruction replay | Final evidence | PENDING |
| `FINAL-ART-010` | Steering 15.1 | Create the final local commit. | FINAL | Exact clean commit and tree audit | Final evidence | PENDING |
| `FINAL-GUARD-001` | Steering 15.1 | Enter `DEVELOPMENT_COMPLETE` only after `RELEASE_READY` and terminal-guard approval. | FINAL | Guard state transition test | Final evidence | PENDING |
| `FINAL-GUARD-002` | Steering 15.3 | Require `PROJECT-STATUS` to record a valid terminal state. | FINAL | Terminal-state mutation | Final evidence | PENDING |
| `FINAL-GUARD-003` | Steering 15.3 | Require the autonomous queue to be empty. | FINAL | Queue mutation | Final evidence | PENDING |
| `FINAL-GUARD-004` | Steering 15.3 | Require P00 through P16 and FINAL to have passed. | FINAL | Phase-status mutation | Final evidence | PENDING |
| `FINAL-GUARD-005` | Steering 15.3 | Require no review with a `FAIL` verdict. | FINAL | Review-verdict mutation | Final evidence | PENDING |
| `FINAL-GUARD-006` | Steering 15.3 | Require no open P0, P1, or P2 finding. | FINAL | Finding-ledger mutation | Final evidence | PENDING |
| `FINAL-GUARD-007` | Steering 15.3 | Require no open remediation. | FINAL | Remediation-state mutation | Final evidence | PENDING |
| `FINAL-GUARD-008` | Steering 15.3 | Require the final gate or terminal tribunal to use the terminal baseline. | FINAL | Baseline mutation | Final evidence | PENDING |
| `FINAL-GUARD-009` | Steering 15.3 | Require every terminal artifact to exist. | FINAL | Artifact deletion mutation | Final evidence | PENDING |
| `FINAL-GUARD-010` | Steering 15.3 | Require every terminal artifact to correspond to the delivered tree. | FINAL | Artifact-content mutation | Final evidence | PENDING |
| `FINAL-GUARD-011` | Steering 15.3 | Force `CONTINUE` when any terminal-guard answer is negative. | FINAL | Guard negative matrix | Final evidence | PENDING |
| `FINAL-GUARD-012` | Steering 15.3 | Never send a nonterminal no-valid-ending message to the user. | FINAL | Terminal transcript test | Final evidence | PENDING |
| `FINAL-USER-001` | Steering 15.1 | Emit exactly one short terminal user response. | FINAL | Terminal response schema | Final evidence | PENDING |
| `FINAL-USER-002` | Steering 15.1 | Include terminal state in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-003` | Steering 15.1 | Include the exact terminal baseline in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-004` | Steering 15.1 | Include principal deliverables in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-005` | Steering 15.1 | Include executed checks in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-006` | Steering 15.1 | Include measured metrics in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-007` | Steering 15.1 | Include residual risks in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-008` | Steering 15.1 | Include only optional external actions in the terminal response. | FINAL | Terminal response field test | Final evidence | PENDING |
| `FINAL-USER-009` | Steering 15.1 | Request no approval in the terminal response. | FINAL | Terminal response negative test | Final evidence | PENDING |
| `OPS-END-001` | Steering 16 | Never end work in an intermediate project state. | All | Project-state terminal test | Final evidence | PENDING |
| `OPS-END-002` | Steering 16 | Never treat a reviewer `FAIL` as a reason to stop. | All | Review failure transition test | Phase evidence | PENDING |
| `OPS-END-003` | Steering 16 | Never send an intermediate blocker list as the project result. | All | User transcript audit | Phase evidence | PENDING |
| `OPS-END-004` | Steering 16 | Never emit an empty response. | All | Turn-end transcript test | Phase evidence | PENDING |
| `OPS-END-005` | Steering 16 | Never claim readiness from superficial file, commit, or test counts. | All | Release-evidence mutation | Final evidence | PENDING |
| `OPS-END-006` | Steering 16 | Never reduce finding severity to pass a gate. | All | Severity chronology audit | Review evidence | PENDING |
| `OPS-END-007` | Steering 16 | Never dismiss reviewer dissent without reproduction. | All | Dissent disposition audit | Review evidence | PENDING |
| `OPS-END-008` | Steering 16 | Never fabricate words, rules, data, metrics, licenses, or results. | All | Provenance and evidence audit | Final evidence | PENDING |
| `OPS-END-009` | Steering 16 | Never use the model as corpus, gold set, or sole validator. | All | Source and reviewer audit | Final evidence | PENDING |
| `OPS-END-010` | Steering 16 | Never conceal an unrun test or environmental limitation. | All | Command and limitation audit | Phase evidence | PENDING |
| `OPS-END-011` | Steering 16 | End only in a valid `DEVELOPMENT_COMPLETE` or `TERMINAL_BLOCKED` state. | All | Terminal state-machine test | Final evidence | PENDING |
