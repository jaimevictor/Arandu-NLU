# P00 Bootstrap Report

Status: `PHASE_PASSED`

## Scope

P00 establishes the fresh Git baseline, user constraints, clean-room and FOSS
policies, requirements traceability, P01 architecture decisions, persistent
state, and review protocol. It does not admit linguistic data or create runtime
crates.

## Bootstrap And Clean Root

- Initial file: `STEERING-NLU-PTBR-SOL-MAX.md`
- SHA-256:
  `15196e479bee08f117cdf92094381bf8423546a251c5c67e47c76c0a3dbf5539`
- Clean-root commit: `fc80e5075c6fcd471ddea5ef6e0ba0a32c7829cd`
- Clean-root tree: `aa621b4243c472beb1e88619537f320596d9b08f`
- Known excluded steering blob:
  `b817259579808ce7f62291f6ab34cc5c7dda849d`

## Decisions

ADRs 0001-0008 resolve clean-room, licensing, scope, Rust/core boundaries,
protocol, quality/performance, review baselines, Home Assistant integration,
and determinism. No decision blocks P01.

## External research

All downloaded repositories remain under `/private/tmp` and are absent from the
project tree. They are either public contract references, rejected, or
quarantined candidates in `docs/clean-room/MATERIALS.yaml`. No corpus is
admitted in P00.

The Sophia study concludes that 98.4%, 20,000 words/s, and approximately 400
utterances/s are separate public claims on incomparable workloads. ADR-0005
defines independent PT-BR gates and prohibits equivalence claims.

## Remediation

Five independent reviews rejected candidate
`d31a0077a0ebd0379e2f21ba35131ce10af49366`. Four of five reviews then rejected
candidate `75f3ecd4a44fef4a837e4d5f40ea013e1aed7e40`; its reproducibility review
passed, while requirements, correctness, tests, and risk found checkpoint,
scanner, material-hash, and traceability defects. The older pre-clean candidate
`1614aba4df4c6bfa1750dc1cb6604487de49eb0c` remains only in the verified
out-of-tree backup bundle. Three independent reviews rejected candidate
`aabe88d76d3cfecf3b3a1f8722b135bc0a24c7d6`; the other two review attempts
ended without a verdict after platform safety interruption, so no report from
that candidate was accepted. Requirements, correctness, tests, and risk then
rejected candidate `af481c7bbc4612a2d13c8033d8676840c76b703d`; reproducibility
passed. Those reviews found missing execution-quality obligations,
noncanonical report-byte acceptance, an unfenced camel-case assignment bypass,
a nested JSON fragment cutoff, and NUL-bearing checkpoint reports. Candidate
`c15d9935f44d2a573ad85f66bf5122ef71ea50eb` followed. Requirements and
reproducibility passed on that subject; correctness, tests, and risk found
Markdown control-prefix, escaped acronym-key, dotted assignment, deep
decoding, report-field ordering, and malformed-row error gaps. Candidate
`7e58b18dec8bcdbb033f8dc5503b4220a799a4ca` then passed reproducibility but
failed requirements, correctness, and risk review; its tests review ended
without a verdict after a platform safety interruption. Those reviews exposed
encoded report-control and unfenced-key bypasses, noncanonical Scope syntax,
URI dot-segment owner changes, unbounded YAML traversal, structured provider
metadata, an unscanned YAML fence form, overbroad fixture exemptions, and
missing atomic phase obligations. Candidate
`4bbcabd7b586b759db5ee7d73c1a3e7fdff9bbaf` with tree
`ed12414ffa2a13b910eb9ce5259de132aaf57ae2` then passed requirements and
reproducibility review but failed correctness, tests, and risk review. Those
reviews found default-ignorable bypasses, non-scalar and over-depth provider
metadata, nested URL starts, quadratic JSON discovery, unbounded report bytes,
autolink control deletion, inline-code credential values, carriage returns in
Scope, incomplete Markdown fence grammar, array fixture exemptions, and
missing direct limit and parser-rescue regressions. Candidate
`6abd2ac56fb978a4f817b9105ea82531b4a7ea7b` attempted that remediation and
passed exact validation, but the executor invalidated it before any review
completed after finding character offsets used as byte offsets in URL slicing;
no report from that aborted review round was accepted. Candidate
`e540c6f1fe076d30abb95ab18f4f2119e4b191b4` then passed exact validation
and all 272 mutations. Tests and reproducibility review passed, while
requirements, correctness, and risk review found missing all-history privacy,
atomic-execution and unknown-domain/capability oracles; Markdown-styled
sensitive keys; multiline YAML fixture continuation; attributed YAML fences;
unscanned structured provider payloads; Git-stat-dependent cleanliness; and
late report-size checks. Those two PASS verdicts became stale when remediation
began. Candidate `3378a0debd725877d35aa0e8eb9f644f5db05be7` then passed exact
validation and all 313 mutations. Correctness, tests, and risk review failed;
requirements and reproducibility ended after platform stream errors and
produced no verdict. The completed reviews found raw HTML-comment and invalid
Markdown-link finding bypasses, a malformed YAML fixture continuation, nested
YAML parser errors and stack exhaustion handled open, and quadratic unmatched
Markdown brackets. Candidate `21a960d026fc0caf716f52a26eebbb635757b574`
then passed exact validation and all 322 mutations. All five reviews failed.
Requirements found vacuous sensitive-operation classification, incomplete
source/derivative transformation lineage, conflicting phase and terminal
verdicts, missing semantic-result timestamp/random-ID prohibitions, and no
atomic Sophia public-claim role oracle. Reproducibility found ambient system Git
configuration in the regression harness. Tests found discarded explicit-YAML
parse/stack failures and a missing assignment-parser stack regression. Risk
found malformed protected JSON accepted. Correctness found quoted-attribute
HTML control splitting, embedded-YAML semantic-key collisions, quadratic
escaped Markdown delimiters, and invalid UTF-8 from valid JSON surrogate pairs.
Candidate `80932bc7d8e5999f0f43997bd043488c8b70a028` then passed exact
validation and all 366 mutations. Requirements and reproducibility review
passed; correctness and tests review failed; risk review was interrupted
before a verdict. The completed reviews found rendered Markdown and HTML
structured provider keys that bypassed protected-key classification,
Markdown labels inside structured strings that were misclassified as YAML,
an unconverted mapping-key parser stack error, and missing copied-path
regression coverage. Those PASS verdicts became stale when remediation began.
Candidate `e49d237e4623809b9b6b75900f055a03e016e8b3` then passed exact
validation and all 377 mutations. Tests review found that reference and
shortcut Markdown images inside structured prose were still classified as
strict YAML; the other four reviews were stopped when that finding invalidated
the candidate.
Candidate `f63a17cece2f2bc8b5f02afb90e5c501dbb6f7d0` then passed exact
validation and all 378 mutations. Risk review found that exact reference-label
matching could leave a normalized or continued definition ahead of a protected
payload, suppressing its scan, and that valid emphasis, list, or pipe prose
after an image was misclassified as YAML. The other four reviews were stopped
when those findings invalidated the candidate.
Candidate `e2d4fbf40f8229033b00ab1616ac2b3259adea8d` then passed exact
validation and all 382 mutations. Before any review completed, executor
counterexample testing found that repeated YAML sequence indicators after an
image could still hide a protected key. All five reviews were stopped and no
report from that candidate was accepted.
Candidate `7fa23d1d9b17602ff29027f41607c40f1a29aeb7` then passed exact
validation and all 392 mutations. Requirements review passed, while
correctness review found that top-level Markdown-prefixed escaped sensitive
keys retained provider-only block extraction and that a standalone YAML
explicit-key indicator was not recognized. The other three reviews were
stopped when those findings invalidated the candidate.
Candidate `b41ccdf7fe17dbba4b0bba539145576e30f617ab` then passed exact
validation and all 395 mutations. Risk and reproducibility reviews passed,
while correctness review found Markdown quote/list container gaps, discarded
standalone node-property and alias context after images, and duplicate or
alias-bearing assignments suppressed by assignment-oracle preservation. The
other two reviews were stopped when those findings invalidated the candidate.
Candidate `151573b0e0e98b6d62cad83b2910092207302e5c` then passed exact
validation and all 403 mutations. Reproducibility review passed, while
correctness review found no-space blockquote controls, flow-wrapped aliases
after protected fixture assignments, and normalized blockquote duplicates.
The same focused probe exposed repeated standalone node properties after an
image. The other three reviews were stopped when those findings invalidated
the candidate.
Candidate `c8767ef585bd39b610c5cb66c6a71c836c29b171` then passed exact
validation and all 410 mutations. Requirements and reproducibility reviews
passed, while correctness review found that preceding Markdown prose hid
same-indent protected siblings and that repeated node properties before a
flow root were not extracted. Tests and risk reviews were stopped when those
findings invalidated the candidate.
Candidate `c0486e2f3dcc7d3803deb404f3c62f51f61b5504` then passed exact
validation and all 413 mutations. Risk review found that an ordinary
same-indent mapping sibling could still split equivalent protected YAML keys
inside a checkpoint report. The other reviews were stopped when that finding
invalidated the candidate.
Candidate `ecfafa36af4a1547c397f0365cbb64b088b240c2` then passed exact
validation and all 451 mutations. Correctness review found that valid
block-context plain keys containing flow punctuation could canonicalize to
protected keys without entering block extraction. Requirements review used a
malformed tuple and produced no valid verdict; the other reviews were stopped
when the correctness finding invalidated the candidate.
Candidate `de0ef1294684556587b39f583b7d50b60877cbb0` then passed exact
validation and all 455 mutations. Requirements, correctness, and risk reviews
independently found that an unspaced hash inside a valid plain YAML key could
canonicalize to a protected key without entering extraction. Tests and
reproducibility reviews were stopped when that finding invalidated the
candidate.
Candidate `c0394b9903d1eafb8cf06559ed9e620cd15f4a40` then passed exact
validation and all 458 mutations. Requirements and correctness reviews failed;
tests, risk, and reproducibility reviews were stopped when those findings
invalidated the candidate. Requirements found a missing response-rendering
boundary; phase-local rather than global AI-origin language, prior/sibling
implementation, and closed-engine prohibitions; incomplete validator-tool
redistribution-rights evidence; conflated precedence and same-level conflict
criteria; and missing traceability for the required edit and search fallbacks.
Correctness found privacy scanning limited to subject ancestry, rendered HTML
declaration control deletion together with visible-autolink deletion, and
accepted repeated command-line options.
On 2026-08-26 the user imposed a prospective convergence cap. The candidate
containing that decision and at most one blocker-only replacement form P00's
remaining budget. The first baseline satisfying the minimum acceptance
contract must be checkpointed without optional refinement.
Candidate `18ec512db0f314bca55f8726b947847089c8753d` then passed exact
validation and all 484 mutations. Risk and reproducibility reviews passed.
Requirements found that the exhausted-round blocked state could not be
represented. Correctness found that checkpoint revalidation dropped tag-only
and custom refs. Tests additionally found direct-tree and merge-result
sensitive-path bypasses plus quadratic malformed-autolink scanning. This is
the one permitted blocker-only replacement round.
This replacement
remediates every reported P0-P2 and the relevant P3 robustness findings, makes
URL extraction byte-correct, and covers a multibyte prefix:

- a reviewer-owned out-of-tree trust tuple plus canonical committed/worktree
  byte and mode binding for both validator launchers and sources;
- pre-Ruby environment sanitization through executable launchers;
- exact FOSS env/Ruby/Psych/libyaml/Git identities and an explicit ambient-host
  boundary;
- complete atomic traceability for 1,486 obligations, including autonomous
  decisions, impediment recovery, phase loops, interruption state, source
  manifests, final artifacts, terminal guards, and individual attack duties;
- explicit P03 component, manifest, and command obligations, Unicode
  equivalence coverage, pure lexicon transforms, isolated morphology
  evaluation and error analysis, early schema rejection, and
  attack-before-remediation chronology;
- exact approved repository owners and alternate-host/encoded Amazon
  counterexamples;
- fail-closed UTF-8, semantic YAML, embedded/duplicate JSON, generic secret,
  residential-data, and index checks with bounded internal errors;
- isolated no-hardlink archive generation, local-attribute independence, and
  correct PAX state handling;
- absolute attested Git use in both validator and mutation suite;
- a distributable single-root history with no reachable steering path/blob;
- a catalog-only token-holding adapter, live per-target Home Assistant
  authorization in the companion, process-memory-only pairing, stable
  cross-connection operation identities, and pre-effect atomicity abstention;
- a pinned companion installation/config/auth/permission/restore contract;
- global and nine-dimension per-stratum Wilson accuracy gates plus
  nine-dimension per-stratum speed gates with 237 distinct cases per stratum;
- an executable evidence-checkpoint validator for the exact P00-to-P01
  transition;
- reviewer-owned hashes and distinct identities for every checkpoint report,
  strict report schemas, regular-file enforcement, and canonical byte deltas
  for every non-report checkpoint file;
- recursive nested material identity validation and the corrected pinned Home
  Assistant permission-contract digest;
- decoded URL/package scanning and camelCase sensitive-key normalization;
- explicit ADR rows for strict protocol parsing and schemas, target
  cardinality, benchmark warmups, Wyoming behavior, supported architectures,
  memory-only state, catalog persistence, and `SOURCE_DATE_EPOCH`;
- independently frozen, nonempty, per-class zero-false-plan suites with
  immutable identities, provenance, coverage, and invalidation rules;
- exact typed-outcome oracles for unknown and stale Home Assistant operations,
  plus schema-minimized DTO privacy that permits required request data while
  rejecting unrelated residential state;
- AST-level rejection of escaped duplicate structured keys in checkpoint
  reports, plus explicit wrong-parent, merge-parent, symlink, and gitlink
  regressions;
- independently sourced gold-oracle lineage that rejects labels established,
  corrected, or validated by project NLU output;
- persistent executor, subagent, writer-scope, primary-evidence, citation,
  counterexample, severity, and read-only review duties;
- product-boundary rows for speech processing, general personal memory, and
  open-domain response generation;
- a global no-supervisor lifecycle gate, split tokenization and identifier
  obligations, and a validation timestamp bound to the evidence record;
- explicit quality, correctness, evidence, efficiency, agent-brief, and
  reviewer-profile obligations from the execution-quality contract;
- canonical whole-report byte grammar, checkpoint NUL rejection, normalized
  unfenced sensitive assignments, and fail-closed nested payload limits;
- Markdown control-prefix normalization, canonical first-position evidence
  fields, acronym-safe structured keys, stable bounded decoding, and explicit
  malformed checkpoint-row errors;
- encoded report-control normalization, exact single-code-span Scope syntax,
  encoded unfenced-key scanning, URI dot-segment resolution, bounded YAML
  traversal, structured provider scanning, both YAML fence forms, and exact
  fixture exemptions;
- default-ignorable removal in decoded scan views, scalar provider metadata
  with a traversal limit, overlapping bounded URL extraction, single-pass
  bounded JSON discovery, and pre-read checkpoint report byte limits;
- rendered Markdown autolink preservation, inline-code credential detection,
  carriage-return-free Scope paths, full Markdown YAML fence markers, and
  scalar-only technical fixture exemptions;
- direct subject/checkpoint semantic YAML depth and parser-stack rescue tests,
  provider/JSON/URL/report limits, and exact 64-pass/65-pass decoding
  boundaries.
- direct byte and executable-mode comparison for every tracked subject and
  checkpoint file, independent of Git stat-cache trust;
- metadata-first checkpoint report-size rejection before whitespace checks,
  private cloning, or validator report-byte reads;
- linearly bounded raw-plus-rendered Markdown control scanning for comments,
  invalid links, styled links, and inline, reference, or shortcut images;
- complete valid whole-block YAML fixture decisions, malformed-continuation
  rejection, and fail-closed recursive JSON/YAML scanning across parser errors,
  comments, sequences, flow forms, and nested strings;
- global reachable-history privacy, a concrete P14 zero-or-all operation
  oracle, and distinct exact no-effect outcomes for unknown domains and
  capabilities;
- exact sensitive-operation classes, complete source and lexical transformation
  lineage, disjoint phase/terminal verdict domains, forbidden semantic-result
  metadata, and Sophia comparison-only source roles;
- system/global Git-config isolation in both the regression launcher and every
  direct Git subprocess;
- strict explicit-YAML and protected malformed-JSON handling, assignment and
  whole-payload stack regressions, and post-load embedded-YAML semantic-key
  checks;
- quote-aware linear HTML stripping, linear escaped-Markdown handling, and
  valid JSON surrogate-pair decoding;
- decoded YAML scalar-key classification, malformed nested-HTML preservation,
  fail-closed lone-surrogate JSON keys, linear unmatched angle destinations,
  and Markdown-link versus YAML-sequence separation.
- rendered Markdown/HTML normalization for parsed protected keys while
  preserving Markdown prose inside structured strings;
- bounded mapping-key parser stack failure conversion and copied
  launcher/source canonical-path regressions.
- explicit inline, reference, and shortcut Markdown-image prose positives and
  leading-image separation from embedded YAML parsing;
- bounded protected-block discovery independent of Markdown reference
  normalization, including nested sequence, inline and standalone explicit
  scalar-key, anchor, tag, and alias payloads after image prose;
- all-key top-level sensitive-block discovery while preserving the dedicated
  generic-assignment oracle;
- bounded Markdown container normalization for YAML block discovery,
  preservation of standalone/value node properties, and duplicate protected
  assignment parsing;
- CommonMark no-space blockquote normalization, normalized whole-document
  parsing for protected assignments, and repeated standalone node-property
  extraction;
- prose-independent protected-block extraction, adjacent same-indent
  protected sibling parsing, and node-property discovery before flow roots;
- complete consecutive same-indent mapping groups after a protected key,
  including ordinary, explicit, merge, and complex siblings between equivalent
  protected keys, plus YAML document boundaries;
- width-preserving Markdown container records, protected block expansion in
  both directions, indentless-sequence and flow-closer handling, flow-set and
  slash-separated protected keys, safety parsing for fixture-led blocks, and
  delimiter-aware exclusion of rendered Markdown labels.
- a separate response-rendering boundary plus global AI-origin language,
  prior/sibling implementation, and closed-engine prohibitions;
- explicit validator-tool redistribution rights and separate precedence and
  same-level decision criteria;
- traceability for the required `apply_patch` editing and `find`/`grep` search
  fallback rules;
- bounded privacy scanning of sensitive paths and blobs reachable from every
  project ref;
- complete rendered declaration, processing-instruction, and CDATA removal
  while preserving visible URI and email autolinks;
- rejection of every repeated validator command-line option.
- a prospective three-round phase cap, explicit minimum acceptance contract,
  immediate first-pass checkpointing, eligible-P3 deferral, blocked
  cap-exhaustion handling, and a stricter remaining-P00 budget.
- bounded direct parsing of every reachable Git tree entry, complete ref
  preservation in checkpoint revalidation, cached linear autolink closing
  searches, and an executable exhausted-budget blocked-state transition.

Each true finding has a mutation regression in
`tools/test-validate-governance.rb`; the regenerated suite passed all 492 cases
and is recorded in `docs/evidence/P00-VALIDATION.md`.

## User-Directed Closeout

On 2026-08-27 the user directed the executor to skip the remaining P00 review
stage and move on if the active 492-case run succeeded. The run passed all 492
cases. The frozen candidate then passed exact governance validation:

- subject commit: `93c2c1e493397c609b0554b54c79b92a15b3c7b8`
- subject tree: `30917ab7c60a678527673e6c84e1b6b74106815f`
- requirements checked: 1486
- open P0-P2 findings: none known

The five P00 independent-review obligations are recorded as `WAIVED`, not
misrepresented as review passes. This is a one-time P00 closeout exception.
The three-round cap, minimum acceptance contract, and required reviews remain
in force for P01 and later phases.
