# User Decisions

These decisions override conflicting steering text.

| ID | Decision | Strength | Owner | Acceptance |
| --- | --- | --- | --- | --- |
| `USR-001` | Do not build or require an external supervisor script. | MUST | all phases | No tracked, packaged, or runtime supervisor script exists. |
| `USR-002` | Aim to cover every Home Assistant domain through measured, fail-closed capability dispositions. | SHOULD | P00, P10, P14 | Pinned domain report lists every domain and its supported or abstaining behavior. |
| `USR-003` | Deliver the product as a Home Assistant app/add-on. | MUST | P14, P15 | Install, integration, upgrade, and rollback tests pass. |
| `USR-004` | Obtain public requirements and contract evidence independently. | MUST | P00, P10, P14 | Every contract source has public provenance and license review. |
| `USR-005` | Obtain every linguistic and evaluation dataset independently. | MUST | P02 | Every dataset passes source admission before use. |
| `USR-006` | Meet or exceed Sophia's public 98.4% accuracy claim on an independent PT-BR gate. | MUST | P15 | ADR-0005 exact-semantic confidence gate passes. |
| `USR-007` | Meet or exceed Sophia's public speed claims on separately defined core and end-to-end gates. | MUST | P15 | ADR-0005 throughput gates pass on documented hardware. |
| `USR-008` | Use only free and open-source project inputs and dependencies. | MUST | all phases | License gate reports no proprietary, NC, ND, research-only, or ambiguous component. |
| `USR-009` | Do not use Amazon-specific or Amazon-internal material, including public AWS/Amazon projects. | MUST | all phases | Ownership, source, package, and endpoint exclusion tests pass. |
| `USR-010` | Limit every phase to three substantive frozen candidate review rounds: one initial round and at most two blocker-remediation rounds. | MUST | all phases | Candidate and review chronology contains no fourth round. |
| `USR-011` | Use the documented minimum acceptance contract for every phase. | MUST | all phases | Phase gate proves mandatory requirements, checks, reviews, finding disposition, and checkpoint validation. |
| `USR-012` | Checkpoint the first minimally acceptable baseline immediately without optional refinement. | MUST | all phases | Checkpoint chronology follows the first passing review round. |
| `USR-013` | Defer eligible P3 improvements instead of extending a phase review loop. | MUST | all phases | P3 disposition records residual eligibility and a later owner or backlog. |
| `USR-014` | Stop a phase as blocked for explicit user scope adjudication when its round budget is exhausted with a P0 through P2 blocker. | MUST | all phases | Exhausted-budget state transition records the remaining blocker and requested decision. |
| `USR-015` | Limit remaining P00 work from 2026-08-26 to the current candidate and at most one blocker-only replacement. | MUST | P00 | P00 candidate chronology contains no later substantive replacement. |
| `USR-016` | After bounded external-source recovery failed, permit a deterministic project-authored synthetic PT-BR conformance corpus with project-authored labels fixed before NLU implementation. | MUST | P02, P15 | The corpus is Apache-2.0, versioned, reproducible, frozen before tuning, never labeled by NLU output, and results are reported only as internal conformance rather than independent accuracy or Sophia equivalence. |
| `USR-017` | Permit one P12 evidence-only proof candidate after the three substantive rounds, limited to independently proving the already-implemented generation bindings. | MUST | P12 | Candidate 4 changes only tests and validators, changes no production or dependency bytes, and all mandatory reviewers pass the exact candidate. |
| `USR-018` | Permit a documented feasible secret-memory compromise when an admitted FOSS runtime cannot prove that every transient transport-secret copy is individually locked and zeroized. | MUST | P13-P15 | Persistent pairing state and private session keys remain only in dedicated fail-closed peer processes whose complete address spaces are locked; one-time provisioning copies are bounded and destroyed best-effort; swap, core dumps, persistence, backups, logs, diagnostics, and telemetry are prohibited; startup fails if process locking is unavailable; and the residual transient-copy risk is reported. |
| `USR-019` | After the exhausted P13 source convergence and candidate reviews, permit exactly one consolidated blocker-only correction that fixes every reproduced P1/P2 finding, admits a separately sourced standardized FOSS transport portfolio, and closes the first passing baseline without optional refinement. | MUST | P13 | The correction is one final integrated candidate, changes only reproduced blockers and their evidence, receives all mandatory same-baseline reviews, and either checkpoints immediately on PASS or records P13 blocked without another correction pass. |
| `USR-020` | After the `USR-019` candidate's source reviews reproduced new source-evidence blockers, continue to 100% project completion and use the best bounded workaround, including project-authored technical source when necessary. | MUST | P13-FINAL | Permit exactly one terminal P13 source-evidence closure candidate limited to those reproduced findings, with no product-code change or optional refinement; checkpoint immediately on PASS or record P13 blocked without another correction. |
| `USR-021` | Continue to 100% project completion after the `USR-020` candidate's independent reviews reproduced three additional evidence-consistency blockers. | MUST | P13-FINAL | Permit one consolidated terminal review correction limited to the stale cross-ledger lock identity, premature legal-code admission state, and private-source post-command integrity verification; change no product, dependency, or external-source bytes; review one frozen replacement and checkpoint immediately on PASS without optional refinement. |
| `USR-022` | After the `USR-021` correction's rights audit reproduced source-origin blockers, use the best bounded source workaround and finish P13 without another refinement loop. | MUST | P13 | Permit exactly one rights-closure candidate: replace resolution-only external packages with project-authored compile-fail technical fixtures, project Poly1305 to the selected forced-soft source set, and bind every selected origin notice to eligible rights evidence; change no product behavior; freeze and checkpoint the first fully passing baseline, with no optional follow-up pass. |
| `USR-023` | After the `USR-022` candidate's independent reviews found that retained noncompiled files and Poly1305's historical Donna chain still prevented source admission, finish P13 through the minimum compile-only source projection and project-authored technical replacement needed to close those findings. | MUST | P13 | Permit one integrated blocker correction that retains exact compilation-reachable package and legal files, removes whole unrelated files, replaces only the forced-soft Poly1305 backend with reviewed Apache-2.0 project source, path-limits advisory reads, and binds every retained origin statement; change no protocol, dependency identity, or product behavior; freeze one replacement and checkpoint immediately on PASS without another refinement pass. |
| `USR-024` | After the `USR-023` candidate's source reviews reproduced incomplete origin detection and notice/election inconsistencies, continue to 100% through one minimum evidence-only correction. | MUST | P13-FINAL | Permit one consolidated P13 blocker correction limited to paragraph-aware origin detection, immutable generic-array Rust-origin evidence, the two required Rust MIT notice additions, and an Apache-2.0 election plus matching projected manifest declaration for the mixed Poly1305 projection; change no protocol, dependency identity, compiled source, or product behavior; checkpoint the first passing baseline without optional refinement. |
| `USR-025` | After the `USR-024` candidate's source reviews reproduced only acquisition, origin-inventory, command-window, lazy-fetch, count, and Linux-proof-scope defects, apply one minimum evidence closeout and move on. | MUST | P13-FINAL | Bind a versioned acquisition replay, the concrete omitted Curve25519 origin, tamper-evident private-tree metadata, explicit Cargo configuration, and fail-closed Git reads; correct stale counts; limit P13 to exact source admission plus host capability and package-graph evidence; require kernel-enforced read-only native Linux builds in P14; change no compiled source, dependency identity, protocol, product behavior, or linguistic input; checkpoint the first passing baseline with no optional refinement. |
| `USR-026` | Finish P13 now through one minimum correction of the four blocker classes reproduced on `2870a1bf806f9e2b046af22f2c286a400ee8910d`, then move directly to P14; continue through 100% project completion without optional review or refinement passes. | MUST | P13-FINAL | Replace P13 Cargo execution with an exact direct-rustc/Clippy plan because the selected Cargo binary contains permanently rejected OpenSSL-derived bytes; complete deterministic source fetch/extraction replay and its tests; bind every concrete omitted retained origin statement; include the containing source directory in substitution detection; freeze one replacement, run only mandatory reviews, checkpoint immediately on PASS, and add no product behavior, dependency identity, protocol, or linguistic input. |
| `USR-027` | After review of the `USR-026` candidate found only bounded validation-identity and stale-evidence defects, finish P13 through one consolidated minimum correction and continue to 100%. | MUST | P13-FINAL | Use only the admitted Ruby runner in tests; make no-Cargo invocation mandatory; bind the full source/tool/output ancestor chain, every direct tool and runtime library, and preexisting generated artifacts around every command; replace stale Cargo probe fields with direct-driver fields; add focused mutation tests; change no source portfolio, product behavior, protocol, dependency identity, or linguistic input; freeze one replacement and checkpoint immediately when mandatory reviews pass. |
| `USR-028` | After review of the `USR-027` candidate reproduced bounded output, sysroot, inherited-Cargo, primary-origin, and notice blockers, apply one final minimum correction and move directly to P14. | MUST | P13-FINAL | Bind exact first-created and inter-command outputs, the complete active target sysroot, Noise and Cacophony Git objects, and complete toolchain notices; make inherited no-Cargo paths genuinely Cargo-free; add the required Poly1305 manifest change notice; freeze one replacement, run mandatory reviews once, and checkpoint the first passing subject without optional refinement. |
| `USR-029` | After the `USR-028` candidate's license review found that the whole-distribution Rust notice did not prove the active tool source closure, obtain the pinned official source and close only that blocker before moving to P14. | MUST | P13-FINAL | Bind the Rust 1.98.0 source archive to the admitted channel manifest, prove that the sole CC0-only package belongs only to excluded rust-analyzer source, bind the selected rustc, Clippy, LLVM, and sysroot source/license roots, add focused mutations, and change no product, protocol, dependency, cryptographic, or linguistic byte. |
| `USR-030` | After review of the `USR-029` candidate reproduced bounded legal-inventory, archive-identity, duplicate-evidence, and queued-request defects, finish P13 through one minimum blocker-only correction. | MUST | P13-FINAL | Expand and partition the exact legal inventory, keep one verified archive descriptor through extraction, bind duplicated source identities, make queued admission deadline-aware, add the exact regressions, and change no transport source, dependency, protocol, linguistic input, or optional feature; freeze one subject and checkpoint immediately on mandatory-review PASS. |
| `USR-031` | Continue to 100% after mandatory reviews of `d64f2c65cb485a897bbf214affeec74907c212b8` reproduced only archive-race, legal-alias, request-lifecycle, and decision-ledger blockers. | MUST | P13-FINAL | Use a private verified unlinked archive snapshot, recognize conventional legal aliases, serialize admitted handling against expiration, join every admitted worker before successful shutdown, restore the missing normative decision, and add exact regressions; change no source portfolio, dependency, protocol, cryptographic byte, or linguistic input; run only mandatory same-subject reviews and advance immediately on PASS without optional refinement. |
| `USR-032` | After review of `06157fd4d42fcbad06c1418eb27cfb1514d81931` reproduced only verified-byte reopening, destination-ancestor races, and admitted-handler lifetime blockers, finish P13 through one consolidated correction and move directly to P14. | MUST | P13-FINAL | Parse each verified crate byte string without reopening its path, keep acquisition and extraction publication descriptor-relative across ancestor replacement, and terminate the dedicated credential-free server process with exit code 70 before an admitted overrun or blocked shutdown can mutate late; add exact regressions, change no selected source, dependency, protocol, cryptographic byte, or linguistic input, and checkpoint the first mandatory same-subject PASS without optional refinement. |
| `USR-033` | After mandatory review of `30329e2524dd86e0e30933cc9d780c341f95858e` reproduced terminal source-name, lazy-fetch, cleanup-race, archive-amplification, release-panic, and scheduler-bound defects, apply one minimum correction and move directly to P14. | MUST | P13-FINAL | Consume only verified archive bytes, prohibit Git lazy fetch, revalidate terminal published names, atomically quarantine and retain uncertain source artifacts, bound all derived archive entries and path depth, unwind release panics, retain server sockets in fresh process-generation directories, and state deadline containment only under OS scheduling; add exact regressions, change no selected external source, dependency identity, protocol, cryptographic byte, or linguistic input, and checkpoint the first mandatory same-subject PASS without optional review or refinement. |
| `USR-034` | After mandatory review of `e04abd50fbd8f598068d975914e4a59787e71839` reproduced only closeout lazy-fetch, terminal-name, archive-depth-test, active-expiry, concurrent-clock-order, legal-discovery, and toolchain-origin-disposition defects, close those blockers now and move directly to P14. | MUST | P13-FINAL | Disable lazy fetch in every closeout Git subprocess, revalidate an existing extraction's terminal identity after its final parent check, test the exact archive-depth boundary, retain expired admitted work for fatal monitoring, serialize clock sampling with stateful dispatch, discover coherent legal grants by content as well as name, and disposition every detected selected toolchain origin statement; add only exact regressions and evidence, change no selected source, dependency identity, protocol, cryptographic byte, or linguistic input, and checkpoint the first mandatory same-subject PASS without another review or refinement pass. |
| `USR-035` | Finish the current P13 run through the minimum correction of the archive-preflight, path-source, and copied-source-rights defects reproduced on `6a1851851091e6f3f0efd7e015331a15bfe86277`, then move directly to P14 and continue to 100%. | MUST | P13-FINAL | Bound selected Rust archive type, size, count, depth, and aggregate bytes before extraction; scan and disposition selected compiler, Clippy, and sysroot path-source roots; bind pulldown-cmark's Redwood copy to the exact author relicensing grant and tracing-subscriber's copy to exact Hyperium MIT/Apache-2.0 source; correct stale extraction prose; run one mandatory same-subject review round and checkpoint immediately on PASS with no optional final review or refinement. |
| `USR-036` | Finish P13 through one minimum correction of the six source and governance defects reproduced on `a4a4f904b68447abcc6d24f00fc87b6aba8634f3`, then advance directly to P14 and continue to 100%. | MUST | P13-FINAL | Open untrusted large paths without blocking; detect the omitted origin vocabulary without treating a Unicode escape as CC0; reject the restrictive Intel CPUID file; bind the LoongArch headers to `GPL-3.0-or-later WITH GCC-exception-3.1`; restore the complete user-decision trace and enforce its completeness; add exact regressions, change no selected source byte, dependency, protocol, product behavior, or linguistic input, and checkpoint immediately after one mandatory same-subject PASS with no optional review or refinement. |
| `USR-037` | Finish P13 through one consolidated correction of the source-review defects reproduced on `89cb007efc15a67b3f2c9af1af8973a7026538fa`, then advance directly to P14 and continue to 100%. | MUST | P13-FINAL | Enforce mixed-witness disposition precedence, detect bare and wrapped current origin statements, bound archive-listing output while consuming it, and make governance-row discovery whitespace-tolerant and free of a fixed future ceiling; add exact regressions and affected evidence only, change no selected source byte, dependency, protocol, product behavior, or linguistic input, and checkpoint the first mandatory same-subject PASS without optional refinement. |
| `USR-038` | After mandatory review of `edf6e2c888c841c423f42a19c110072f3b6f7ec7` reproduced bounded validator and evidence defects, finish P13 through one minimum blocker-only correction and advance directly to P14. | MUST | P13-FINAL | Make both decision-row parsers whitespace-tolerant and malformed-ID fail-closed; detect the reproduced current origin statements without cross-statement rejection and bind rejection semantics; bound silent extraction and prohibit escaped descendants; make YAML candidate extraction linear and bounded; enforce coherent post-P00 blocked lifecycle state; add exact regressions and affected evidence only; freeze one replacement and checkpoint the first mandatory same-subject PASS without optional refinement. |
| `USR-039` | After mandatory review of `95d0eda79737d1be180f69f7560d51e619f84758` reproduced only final bounded source-discovery, governance, and existing-tree verification blockers, finish P13 immediately through one minimum correction and advance directly to P14. | MUST | P13-FINAL | Restore the three exact retained origin witnesses and statement-local rejection; reject decorated malformed decision rows and embedded phase tokens; enforce coherent lifecycle states and bounded existing-tree verification; add exact regressions and affected evidence only, change no selected source byte, dependency, protocol, product behavior, cryptographic behavior, or linguistic input, and checkpoint the first mandatory same-subject PASS without optional refinement. |
| `USR-040` | Keep P13 closed, stop all P13 patches, and advance immediately through the remaining project with the safest bounded workaround where the current host cannot execute a phase gate. | MUST | P14-FINAL | P14 may transfer native Linux amd64/aarch64 build and execution to P15 only while artifact production remains disabled; record the limitation without claiming success, freeze the first otherwise passing P14 candidate, run only mandatory reviews, and do not add optional refinement. |
| `USR-041` | After P14 exhausted its candidate budget with reproduced P0-P2 blockers, permit one exceptional integrated blocker-only correction and continue to 100%. | MUST | P14-FINAL | Correct all twelve reproduced blocker classes without optional features or weakened requirements; freeze one integrated replacement, run only the six mandatory same-subject reviews, checkpoint immediately on unanimous PASS, or return P14 to blocked without a second correction. |
| `USR-042` | After all six mandatory reviews of the `USR-041` subject failed, authorize one terminal integrated P14 correction and continue the project. | MUST | P14-FINAL | Correct only the ten consolidated blocker classes recorded at `70a98ca89988c7d112e5b244673db443d9e46226`; freeze one replacement, run one six-role same-subject review round, advance immediately on unanimous PASS, or return P14 to blocked without another correction. |
| `USR-043` | After all six mandatory reviews of the `USR-042` subject failed, authorize one last integrated P14 blocker-remediation pass and then move on. | MUST | P14-FINAL | Correct only the fourteen blocker classes recorded at `aeac316eafa065b8c36fece92afa9c6b333c2eea`; preserve P13 byte for byte; freeze one replacement; run the complete P14 gate and one six-role same-subject review round; advance to P15 only on unanimous PASS, otherwise record the terminal blocked result without another P14 correction. |
| `USR-044` | Move to P15 now without claiming P14 passed. | MUST | P14-FINAL | Freeze `93ed8d75a4cb35f80572f8207105929b0071f48e` as a P14 preflight-only baseline; record the unrun clean exact-subject gate, exhaustive governance mutation suite, and six-role review set; keep release artifacts and both architectures disabled; activate P15; and do not claim P14 or release readiness until the debt is explicitly closed. |
| `USR-045` | Reopen P14 and P15 after the blocked qualification checkpoint, freeze a fresh untouched project-authored synthetic evaluation lineage before behavior changes, correct the reproduced safety and zero-plan blockers, and continue through native release qualification. | MUST | P14-FINAL | One pre-remediation corpus freeze precedes every behavior change; only eligible non-held-out evidence informs remediation; the new held-out and performance splits remain sealed; inherited P14 debt, native Linux, real Home Assistant, performance, packaging, reviews, and terminal gates all pass without waiver. |
| `USR-046` | Invalidate P02-v2 after the recorded post-remediation performance-record exposure, freeze a clean P02-v3 lineage before reapplying remediation, and continue through P15, P16, and FINAL. | MUST | P15-FINAL | Permanently exclude P02-v2 from release qualification; freeze new v3 identities and bytes before reapplying the preserved remediation; keep v3 held-out, performance, and suite records sealed from the executor and remediation agents; retain every ADR-0047 native, real-runtime, packaging, review, and terminal requirement. |
| `USR-047` | Continue autonomously through P15, P16, and FINAL without further scope prompts; authorize the exhausted P02-v3 blocker-only replacement and all remaining in-scope blocker remediation. | MUST | P15-FINAL | Bind authorization-parent I/O sources by immutable blob identity; predeclare and mark every future mutable I/O path before the corpus freeze; preserve all clean-room, FOSS, sealed-data, native-platform, real-runtime, packaging, review, and terminal requirements; never substitute weaker evidence merely to avoid a stop. |
| `USR-048` | Replace the repeatedly exhausted P00-P16 tribunal with a bounded minimum lovable product and continue through final delivery without another scope stop. | MUST | MLP | Preserve the FOSS, clean-room, offline, deterministic, fail-closed, privacy, and Home Assistant execution boundaries; support coordinated target chaining and ordered mixed-effect chaining, light/switch control, mandatory fan percentage control, and read-only sensor state; use one ordinary gate and two focused release reviews; retain older phase artifacts only as historical evidence. |

`USR-016` supersedes `USR-005` for the P02 corpus and supersedes the
independent-accuracy portion of `USR-006`. The numerical 98.4% conformance
threshold remains; an independently sourced accuracy claim requires a future
eligible external evaluation.

`USR-017` is a one-phase evidence exception, not another substantive
implementation or refinement round. It does not weaken `USR-010` for P13 or
later phases.

`USR-018` supersedes only ADR-0007's unimplementable claim that every
runtime-created and provisioning copy can be proven individually locked and
destroyed. It does not weaken mutual authentication, encryption, pairing
freshness, restart revocation, credential isolation, or the prohibition on
persistence and disclosure.

`USR-019` is the explicit P13 scope adjudication required by `USR-014`. It
supersedes `USR-010` only for this one consolidated P13 correction and does not
restore an unused refinement budget. It does not weaken safety, correctness,
licensing, provenance, clean-room, test, review, or minimum-acceptance
requirements. P14 and later phases retain the ordinary three-candidate cap.

`USR-020` records the newer instruction to continue after the `USR-019`
candidate failed source review. It supersedes only `USR-019`'s terminal-block
branch for one source-evidence closure candidate. The candidate may correct
the RustSec license binding, Fiat notice inventory, Cargo capability isolation,
and Cacophony Git identity evidence reproduced by independent review. It may
not alter product behavior, add optional refinement, or create a further P13
candidate entitlement.

`USR-021` records the still newer instruction to continue without stopping
before project completion. It supersedes only `USR-020`'s terminal-block
branch for one consolidated correction of the three blocker classes reproduced
on `c3592db753814c36640a4e8a9b43492e6843bcfc`. The correction may update
source-admission ledgers, verifier predicates, technical mutation tests, and
this decision chronology. It may not change the selected portfolio, any
external-source byte, dependency resolution, product code, or runtime
behavior, and creates no optional-refinement entitlement.

`USR-022` records the instruction to find an eligible source or create the
minimum project-authored workaround where necessary. It supersedes only
`USR-021`'s terminal-block branch for one rights-closure candidate. The
candidate may remove resolution-only external source from the admitted
closure, replace it with deterministic Apache-2.0 `FIXTURE_TECNICA` packages
that fail if compiled, retain only Poly1305 bytes selected by the forced-soft
build, bind typenum's copied `num::pow` implementation to immutable rust-num
MIT/Apache-2.0 evidence, and enforce an exact selected-source origin-notice
inventory. It may not change product code or transport behavior. The first
baseline passing all mandatory gates and reviews checkpoints immediately;
there is no optional refinement pass.

`USR-023` records the newer instruction to continue through full project
completion and to create the source workaround when external rights evidence
cannot be closed. It supersedes only `USR-022`'s terminal-block branch. The
candidate may project all 23 selected packages to the exact union needed by
the forced host, amd64 Linux, and aarch64 Linux builds; retain every applicable
license and obligation-bearing notice; replace the selected Poly1305 software
backend with independently reviewed project-authored Apache-2.0 source; and
correct the reproduced RustSec and origin-inventory verifier defects. It may
not change the Noise profile, Snow feature set, package identities, transport
behavior, linguistic inputs, or product code. Mixed source files are retained
without byte-range editing. The first passing immutable baseline checkpoints
immediately, and no optional refinement or further P13 candidate is authorized.

`USR-024` records the continuing instruction to finish the whole project after
independent review of the `USR-023` candidate found only source-evidence
blockers. It supersedes only `USR-023`'s terminal-block branch for one
consolidated correction. The correction may add deterministic notices formed
from the exact rust-num and Rust PR 49000 source headers plus their exact MIT
grants to typenum's and generic-array's projected legal surfaces, bind the
generic-array Rust origin and referenced `COPYRIGHT` immutably, widen the
origin scanner to wrapped statements, and elect Apache-2.0 for the mixed
upstream/project Poly1305 projection while replacing only its projected
manifest license declaration to state that election. It may not change
compiled source bytes, package resolution, transport behavior, protocol,
product code, or linguistic inputs. The first passing immutable baseline
checkpoints immediately with no optional refinement.

`USR-025` records the continuing instruction to finish rather than reopen
transport selection or an unbounded P13 refinement loop. It supersedes only
`USR-024`'s terminal-block branch for one consolidated correction of findings
reproduced on `ec7e99c5b66a842c5122e4ab1380fab802380067`. P13 may rely on
tamper-evident device, inode, and change-time checks plus an explicit sealed
Cargo configuration under its unprivileged local validation boundary; it does
not claim protection from a privileged host attacker or native Linux
file-reachability proof. P14 must establish a kernel-enforced read-only source
snapshot and native amd64/aarch64 builds before product admission. The
correction may add acquisition tooling and evidence predicates but no product
or external implementation byte. The first baseline passing the mandatory
same-subject reviews checkpoints immediately, with no optional follow-up.

`USR-026` records the newer instruction to correct the exact blockers returned
for `2870a1bf806f9e2b046af22f2c286a400ee8910d` and move on. It supersedes only
`USR-025`'s terminal-block branch for this one integrated replacement. The
correction may remove Cargo from the P13 execution path, add a deterministic
direct compiler driver and technical tests, complete acquisition extraction
replay, widen the origin inventory only for concrete retained statements, and
bind the containing source directory against rename/substitute/restore. It may
not reopen transport selection, alter selected external or cryptographic source
bytes, change product behavior, or create another refinement entitlement.
Mandatory source and phase reviews still apply to the frozen replacement; a
passing baseline checkpoints immediately and advances to P14 without an
optional final-review pass.

`USR-027` records the instruction to use the best bounded workaround and keep
moving after review of
`4c75002728e4c84b28d304dc8fc3707446b16262`. It supersedes only
`USR-026`'s terminal-block branch for one consolidated validation correction.
The correction may remove unadmitted test executables, require the explicit
no-Cargo aggregate mode, bind the omitted compiler runtime library, extend
command-window identity through every lexical and resolved ancestor and every
preexisting generated artifact, and correct direct-driver evidence fields.
It may not alter selected external or cryptographic source, product code,
protocol, dependency identity, transport behavior, or linguistic inputs.
Mandatory same-subject reviews still apply; the first passing baseline
checkpoints immediately without optional refinement.

`USR-028` records the latest instruction to fix the current P13 issues once and
move on. It supersedes only `USR-027`'s terminal-block branch for the findings
reproduced on `56c66e5303a329ae7f19e485d05f179bdcb8c59a`. The correction
may add exact generated-output identities, bind the active Rust target sysroot,
remove inherited Cargo execution, require the two missing primary Git origins,
and close the identified notice obligations. It may not change package
identity, cryptographic implementation source, product behavior, protocol, or
linguistic input. The first passing immutable replacement checkpoints
immediately; no optional refinement or final-review pass follows.

`USR-029` records the continuing instruction to use the best available source
workaround and finish the project after license review of
`89bd61750795301b7975449e7fa29e75b189bf36`. It supersedes only
`USR-028`'s terminal-block branch for the reproduced Rust toolchain
source-closure finding. The correction may acquire and bind the already-pinned
official Rust 1.98.0 source archive, separate selected compiler, Clippy, LLVM,
and sysroot roots from excluded rust-analyzer source, and add source-license
verification and mutations. It may not admit CC0 software, change selected
tool binaries, product or transport code, dependencies, protocol, or
linguistic input, and creates no optional refinement entitlement. The first
same-subject mandatory review set that passes checkpoints immediately.

`USR-030` records the instruction to wrap up P13 after review of
`41ea528df9b6163a9a08a297d21c9c8f8c18b386`. It supersedes only the
`USR-029` terminal-block branch for the five reproduced blocker classes. The
correction may update exact source evidence, its verifier and technical tests,
and the bounded server admission state machine. It may not change selected
source or dependency bytes, protocol, cryptographic behavior, or linguistic
input. The first same-subject mandatory review set that passes checkpoints
immediately and creates no optional refinement entitlement.

`USR-031` records the newer instruction to continue through full project
completion after review of
`d64f2c65cb485a897bbf214affeec74907c212b8`. It supersedes only the
`USR-030` terminal-block branch for the reproduced same-inode archive rewrite,
conventional legal-name omission, post-admission timeout mutation, detached
shutdown worker, and missing decision-ledger findings. The correction may
snapshot the already-verified archive into a private unlinked descriptor,
widen only the technical legal-name classifier, serialize request expiration
with an admitted handler, join admitted workers, and repair governing evidence
plus exact regressions. It may not reopen source selection or change external
source, dependency, protocol, cryptographic, or linguistic bytes. The first
mandatory same-subject PASS checkpoints immediately and advances to P14 with
no optional review or refinement pass.

`USR-032` records the instruction to wrap up the current phase and continue to
100% after review of
`06157fd4d42fcbad06c1418eb27cfb1514d81931`. It supersedes only the
`USR-031` terminal-block branch for the three reproduced P2 blocker classes.
The correction may consume exact bytes already returned by verification,
replace path-based destination publication with held-directory operations,
and isolate arbitrary request handlers behind fatal dedicated-process
containment. It may update only the corresponding technical tests, validators,
decision and architecture records, and self-binding evidence. It may not
reopen source selection or change external source, dependency, protocol,
cryptographic, or linguistic bytes. The first mandatory same-subject PASS
checkpoints immediately and advances to P14 with no optional review or
refinement pass.

`USR-033` records the continuing instruction to finish P13 and the project
after mandatory reviews of
`30329e2524dd86e0e30933cc9d780c341f95858e`. It supersedes only the
`USR-032` terminal-block branch for the reproduced verified-byte, lazy-fetch,
terminal-name, cleanup-race, archive-amplification, release-panic, and
scheduler-bound findings. Source acquisition may atomically move an uncertain
entry to a no-clobber quarantine and retain it; the server retains its socket
name instead of attempting raceable cleanup. Release panic handling must
unwind so the worker guard can request process exit. Deadline containment is
an application guarantee conditional on the relevant process threads being
scheduled; no in-process mechanism claims a scheduler-independent wall-clock
maximum. P14 must allocate a fresh private socket directory for every server
process generation. The correction changes no selected external source,
dependency identity, protocol, cryptographic byte, or linguistic input. The
first mandatory same-subject PASS checkpoints immediately and advances to P14.

`USR-034` records the continuing instruction to finish the current phase after
mandatory reviews of
`e04abd50fbd8f598068d975914e4a59787e71839`. It supersedes only the
`USR-033` terminal-block branch for the seven reproduced blocker classes.
The correction may update exact source replay, legal and origin evidence,
their validators and technical regressions, and the two bounded server state
machines. It may not reopen source selection or change selected external
source, dependency, protocol, cryptographic, product-behavior, or linguistic
bytes. The first mandatory same-subject PASS checkpoints immediately and
advances directly to P14; no optional review or refinement follows.

`USR-035` records the latest instruction to compromise where needed, finish
the current phase now, and continue without stopping before full project
completion. It supersedes only the `USR-034` terminal-block branch for the
three evidence defects reproduced on
`6a1851851091e6f3f0efd7e015331a15bfe86277`. The correction may add bounded
archive metadata preflight, conservative selected path-source observation,
exact copied-source Git and author-permission evidence, corresponding
technical mutations, and self-binding evidence. It may not change selected
toolchain or transport source bytes, dependency identity, protocol,
cryptographic behavior, product behavior, or linguistic input. The first
mandatory same-subject PASS checkpoints immediately and advances to P14; no
optional final review or refinement follows.

`USR-036` records the newer instruction to use the best available workaround
and continue after independent audit of
`a4a4f904b68447abcc6d24f00fc87b6aba8634f3`. It supersedes only the
`USR-035` terminal-block branch for the reproduced FIFO, origin-vocabulary,
CC0-escape, Intel-rights, LoongArch-license, and governance-completeness
defects. The correction may update source-evidence classification, exact legal
bindings, technical regressions, the decision ledger, traceability, and
self-binding evidence. It may not change selected external source bytes,
dependency identity, protocol, cryptographic behavior, product behavior, or
linguistic input. The first mandatory same-subject PASS checkpoints
immediately and advances to P14 without another review or refinement pass.

`USR-037` records the continuing instruction to finish P13 and the complete
project after review of
`89cb007efc15a67b3f2c9af1af8973a7026538fa`. It supersedes only the
`USR-036` terminal-block branch for mixed-witness disposition precedence,
bare and wrapped origin discovery, bounded archive-listing capture, and
complete whitespace-tolerant governance-row discovery. The correction may
update only source-evidence classification, bounded process-output handling,
governance parsing, exact technical regressions, review history, and
self-binding evidence. It may not change selected external source bytes,
dependency identity, protocol, cryptographic behavior, product behavior, or
linguistic input. The first mandatory same-subject PASS checkpoints
immediately and advances to P14 without optional refinement.

`USR-038` records the newer instruction to finish the phase immediately after
mandatory review of
`edf6e2c888c841c423f42a19c110072f3b6f7ec7`. It supersedes only the
`USR-037` terminal-block branch for the reproduced decision-parser,
origin-discovery, rejection-scope, digest-binding, extraction-output,
descendant-containment, YAML-amplification, and lifecycle-coherence defects.
The correction may update only validators, technical regressions, affected
source evidence, review history, and self-binding governance evidence. It may
not change selected external source bytes, dependency identity, protocol,
cryptographic behavior, product behavior, or linguistic input. The first
mandatory same-subject PASS checkpoints immediately and advances to P14
without optional refinement.

`USR-039` records the latest instruction to finish P13 immediately after
mandatory review of
`95d0eda79737d1be180f69f7560d51e619f84758`. It supersedes only the
`USR-038` terminal-block branch for the three dropped retained origin
witnesses, same-line rejection scope, decorated malformed decision rows,
phase/lifecycle coherence, and existing-tree verification bounds. The
correction may update only source and governance validators, exact technical
regressions, affected evidence, decision records, and self-binding hashes. It
may not change selected external source bytes, dependency identity, protocol,
cryptographic behavior, product behavior, or linguistic input. The first
mandatory same-subject PASS checkpoints immediately and advances to P14
without optional review or refinement.

`USR-040` records the newer instruction that P13 is immutable and the project
must move on immediately, compromising only where necessary. The current
macOS arm64 host has no admitted Linux container, virtual-machine, or emulator
executor. P14 therefore may transfer its native amd64/aarch64 build and
execution gate to P15 instead of selecting an unreviewed executable or
extending P14. This is a scope transfer, not a successful native result:
add-on artifact production remains disabled, the selected source promotion
remains pending native admission, and P15 must close the gate before enabling
or distributing either architecture.

`USR-041` records the explicit P14 scope adjudication after the bounded stop.
It supersedes `USR-010` only for one integrated correction of the findings
recorded in `docs/reviews/P14/blocker-summary.md`. It does not waive
`USR-011`, restore an unused refinement budget, reopen P13, or weaken safety,
correctness, licensing, provenance, clean-room, test, review, or transferred
P15 requirements. The correction freezes once; any mandatory-review failure
returns P14 to blocked without another correction entitlement.

`USR-042` records the user's explicit authorization after every mandatory
reviewer failed the sole `USR-041` correction. It supersedes only ADR-0041's
no-second-correction branch for the ten consolidated classes in
`docs/reviews/P14/blocker-summary.md`. It restores no ordinary candidate or
refinement budget, leaves P13 immutable, and permits no optional feature,
linguistic input, source-selection, safety, privacy, licensing, provenance,
clean-room, test, review, or P15-transfer change. The terminal correction
freezes once and receives one mandatory six-role same-subject review round.

`USR-043` records the user's explicit authorization for one last P14 pass
after all six mandatory reviews of
`e2ab301bad38caeaa2f32664bf442501eb8804df` returned `FAIL`. It supersedes
only ADR-0042's no-further-correction branch for the fourteen blocker classes
frozen at `aeac316eafa065b8c36fece92afa9c6b333c2eea`. The pass unit is one
integrated implementation and evidence approach selected from those blockers
and then frozen, dispositioned, or rejected. Minimum acceptance requires an
exact regression for every blocker, the complete P14 gate, no P13 byte
change, and six independent `PASS` verdicts on one immutable subject. It
restores no ordinary phase round, optional refinement, or scope beyond those
blockers.

`USR-044` records the newer explicit instruction to stop waiting on P14 and
move to P15 immediately. It supersedes only ADR-0043's requirement to remain
in P14 until the final remediation receives unanimous review. It does not
convert preflight evidence into a phase PASS, waive an unrun gate or review,
authorize artifact or architecture enablement, or weaken any final release
requirement. The frozen P14 baseline and its validation debt remain auditable
and must be closed before P14 or release readiness can be claimed.

`USR-045` records the user's explicit instruction to perform every action
requested by the P15 blocked checkpoint. It supersedes only the terminal-stop
branches of `USR-043`, `USR-044`, and ADR-0045 for one resumed integrated
P15 convergence pass. Before any behavior-affecting byte changes, the pass
must freeze a fresh deterministic P02 qualification lineage whose held-out
and performance records remain sealed. The correction may close the exact
restart-durability, helper-ownership, zero-plan, evaluator-binding, native,
real-runtime, performance, packaging, and reconciliation blockers. It does
not waive a gate, permit old release-split tuning, admit a proprietary or
Amazon-specific input, substitute cross/emulated evidence for native
execution, or create an optional refinement entitlement.

`USR-046` records the user's explicit authorization after a bounded
repository search accidentally displayed P02-v2 performance records after
remediation began. It invalidates P02-v2 for release qualification and
permits one clean P02-v3 evaluation restart from the immutable
pre-remediation baseline. P02-v3 must freeze before the preserved remediation
delta is reapplied, use wholly new release identities and bytes, and keep all
held-out, performance, and suite records sealed from the executor and
remediation agents. The authorization does not permit tuning from P02-v2,
weaken any ADR-0047 acceptance condition, restore optional refinement, or
substitute cross-compiled, emulated, mock-only, proprietary, or
Amazon-specific evidence for mandatory native and real-runtime results.

`USR-047` records the user's explicit instruction to continue all the way to
the end without another scope prompt after the P02-v3 freeze review budget was
exhausted. It supersedes only ADR-0048's exhausted-round stop and prospectively
authorizes minimum blocker-only corrections within the existing repository
scope. The immediate replacement must bind authorization-parent source bytes
through immutable Git blob identities and must freeze all future mutable I/O
paths before product remediation resumes. This authorization does not waive a
hard requirement, permit optional refinement, expose sealed records, or turn
an unavailable native or real-runtime result into a PASS.

`USR-048` records the user's newer conclusion that repeated budget exhaustion
is itself evidence of a flawed delivery process. It supersedes the P00-P16
queue, mandatory six-review tribunal, frozen-candidate round budgets,
self-hashing governance gates, native dual-architecture release
qualification, sealed benchmark program, and terminal-guard mechanics for the
MLP. It also supersedes earlier breadth and benchmark targets, including
all-domain coverage and the Sophia comparison. It does not weaken the FOSS,
Amazon-exclusion, clean-room, privacy, local-only, deterministic, fail-closed,
or companion-only execution boundaries. The active MLP supports a bounded
ordered plan, coordinated entity/area targets, and mixed effect actions such
as `apague X e ligue Y`; fan percentage is mandatory, while sensor reading is
a small read-only inclusion. Its corpus is frozen before the new engine and
is internal conformance evidence only.
