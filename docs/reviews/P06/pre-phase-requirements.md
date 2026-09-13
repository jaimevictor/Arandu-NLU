# P06 Pre-phase Requirements Analysis

- Role: `independent-requirements-analysis`
- Analysis instance: `01a04ae3-319c-78b2-87b8-6a6abdfc3eea`
- Input baseline: `901f2665027516c671d372ae1b3d227b49e0092d`
- Input tree: `88b244e990382a53ceebab27330b5ccce00bbad0`
- Mode: read-only repository analysis
- Independence: `INDEPENDENT_READ_ONLY_AGENT`
- Result: `ANALYSIS_COMPLETE_NO_BLOCKER`

## Mandatory Scope

P06 owns these exact requirements:

| ID | Minimum obligation | Required evidence |
| --- | --- | --- |
| `P06-LEX-001` | Import only policy-eligible admitted material. | Admission identity and coordinated-rewrite negatives. |
| `P06-LEX-002` | Keep a source ID on every entry. | Full source, artifact, and runtime-entry audit. |
| `P06-LEX-003` | Preserve every conflicting analysis. | Multi-analysis lookup and permutation tests. |
| `P06-LEX-004` | Build read-only runtime indexes. | Private-storage and shared-reference API audit. |
| `P06-LEX-005` | Emit byte-stable lexicon artifacts. | Two-build and input-permutation equality. |
| `P06-LEX-006` | Remove every entry from a removed source. | Empty-current-source and selective multi-source tests. |
| `P06-LEX-007` | Keep lexical transforms pure. | Replay, input-immutability, and ambient-input audits. |
| `P06-LEX-008` | Keep ordered immutable lineage and derivative license per entry. | Full-entry field and substitution audit. |
| `ARC-DATA-001` | Fail closed while importing data. | Corruption and no-partial-output tests. |
| `DAT-REMOVE-001` | Remove every derivative contribution by source ID. | Artifact, manifest, and index scan after removal. |

The P06 rows are at
`docs/evidence/REQUIREMENTS-TRACEABILITY.md:1088`; the two inherited rows are
at lines 618 and 749. All are present in the machine requirement manifest.

P06 does not own morphology inference, contextual POS selection, intent,
entity resolution, policy, execution, or response rendering.

## Eligible Source

The frozen P02 lexicon is eligible for this bounded purpose. `USR-016`
authorizes the `PROJECT_AUTHORED_SYNTHETIC` corpus, and source policy permits
that state to influence deterministic language packages and internal
conformance. The source manifest records:

- source ID `project-authored-synthetic-ptbr-v1`;
- authorization `USR-016`;
- immutable version `1.0.0`;
- Apache-2.0 source and derivative license;
- intended use `deterministic_internal_conformance_and_language_package`;
- lexicon path `data/project-authored/p02-v1/lexicon.jsonl`;
- 33 records, 9,835 bytes, and SHA-256
  `727e89195fc2ed16489c24b17841d58a2a9bb68c828769ece83ab70489316e4e`.

This source is not independent human-language evidence and cannot support an
independent accuracy, representativeness, or product-equivalence claim. P06
may compile its exact frozen facts but may not add, correct, infer, translate,
or filter PT-BR facts.

The source rows already carry source, corpus, generator, locale, and license
identity. P06 must add the complete immutable locator, ordered transform
lineage, output hashes, split assignment, and derivative-license identity
required by `docs/clean-room/SOURCE-POLICY.md:102`.

No additional external-source search is authorized or necessary. P02's
bounded recovery was exhausted, and `USR-016` resolved it without admitting
any rejected candidate.

## Minimum Acceptance

The first minimally acceptable candidate must:

1. pin and verify the exact admitted source-manifest, lexicon, generator
   specification, generator implementation, and license identities;
2. import all 33 rows without changing their linguistic fields;
3. give every compiled entry a source locator, source-record hash, ordered
   transform hashes, frozen `shared` partition, and Apache-2.0 derivative
   license;
4. retain both analyses for the one repeated source surface and return both
   in stable order;
5. expose immutable lookup and identity indexes with no caller-supplied
   linguistic artifact path;
6. reproduce identical bytes across clean roots and input permutations;
7. remove the sole current source to a valid empty artifact and prove
   selective retention with non-linguistic `FIXTURE_TECNICA` structures;
8. reject coordinated identity, lineage, license, framing, count, ordering,
   and hash substitutions before making a runtime index available;
9. pass inherited P01 through P05 gates and all mandatory reviews for one
   immutable candidate.

## Exclusions

- No new words, lemmas, parts of speech, features, aliases, or paradigms.
- No case folding, accent removal, fuzzy matching, ranking, or winner
  selection.
- No rejected, quarantined, model-generated, closed-engine, Amazon-specific,
  or sibling-directory material.
- No filesystem, network, locale, time, entropy, or mutable-global input in
  runtime lookup.
- Technical fixtures remain structural tests and never enter the shipped
  artifact or linguistic metrics.

## Bounded Convergence

One convergence pass is one integrated source pin, contribution schema,
artifact format, immutable index, and removal design. P06 permits at most
three passes and three frozen candidate rounds. Candidate round 1 is the
initial full review; rounds 2 and 3 are blocker-only. The first passing
candidate is frozen immediately, and optional refinement is deferred.

## Counterexample

A single-value map keyed by surface can process the two existing analyses for
the repeated surface in opposite orders and retain a different winner. That
would hide a source conflict and make output order-dependent even if the map
serialization itself were deterministic.

Evidence inspected: `AGENTS.md`, `docs/clean-room/USER-DECISIONS.md`,
`SOURCE-POLICY.md`, `BOUNDARY.md`, P06 and inherited requirement rows,
ADRs 0001 and 0009, the P02 source manifest, specification, lexicon, source
discovery record, and the P05 handoff.
