# ADR-0014: Conservative contextual POS and isolated training/evaluation

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P08-P09

## Context

P08 must compare a simple POS baseline with one local deterministic contextual
approach, reproduce an offline training artifact, audit sentence/document/origin
splits, and measure unknown and ambiguity behavior.

The only eligible POS labels are the pre-engine P02
`project-authored-synthetic-ptbr-v1` records. They contain 80 train, 80
development, and 81 heldout sentences. All 241 sentences share one source
origin and only four template families. Results are therefore same-source
internal conformance, not independent Portuguese accuracy or generalization.

P07 returns all exact lexical analyses and deliberately does not rank its one
noun/verb conflict. P05 provides a source-backed numeric token class. P08
cannot invent a tag for any other unknown surface.

## Decision

Add a typed POS evidence API to `lang-ptbr`:

```text
PosLookup =
  Unknown
  | Unique(PosCandidate)
  | Ambiguous(PosCandidateSet)
```

The baseline processes each token independently. P07 lexical analyses become
POS candidates without loss of lexical provenance. A P05 `Number` token
becomes `NUM`, as established by the admitted train split. No other token
class or unknown surface receives a POS candidate.

The selected model is a presence-only set of POS transitions observed in the
physical train slice, including beginning and end boundaries. For an
ambiguous token, only its original immediate neighbors are considered. A
unique neighbor or sentence boundary may support candidates through one
observed transition. Context narrows the token only when the union of support
contains exactly one candidate. Missing, multiple, or contradictory support
preserves the complete baseline set.

Selection is non-cascading: a narrowed result never becomes evidence for
another token in the same sentence. Unique candidates never change, and
unknown tokens remain payload-free barriers. There are no probabilities,
weighted counts, smoothing, floating point, position features, surface
features, repairs, generated facts, or package-order tie-breaks.

## Artifact

`nlu-data` compiles a canonical package with magic `NLUPOS\0`, format version
1, at most eight labels, at most 100 sorted unique transitions, and a 16 KiB
limit for each package and manifest.

The manifest binds:

- model, algorithm, compiler, and configuration identities;
- fixed seed `0` and `randomness_used: false`;
- source, corpus, generator, license, locale, and immutable source hashes;
- physical train-slice and train case/document/origin digests;
- train sentence/document/token counts;
- label, transition, package size, and package hashes.

The decoder rejects malformed framing, unknown endpoints, duplicate or
noncanonical records, invalid boundaries, trailing bytes, open or noncanonical
manifests, identity substitution, hash mismatch, and one-over limits.
`lang-ptbr` embeds and decodes the package without filesystem or network
access.

## Access Boundary

A deterministic compiler creates byte-preserving physical train,
development, and heldout slices and proves their complete sentence and
document disjointness. The model trainer receives only train. The algorithm,
configuration, seed, model format, scorer, and acceptance contract were
committed before heldout evaluation.

Development may confirm the predeclared behavior but cannot alter it. Heldout
is available only through the frozen evaluation leaf:

```text
pos-eval -> lang-ptbr -> nlu-data
pos-eval -> nlu-data
```

Production crates cannot depend on the evaluator or access split labels,
expected POS, case identities, evaluation schemas, or reports.

The evaluator applies one scorer to baseline and selected outputs. It emits
integer-only aggregate token-set, candidate-count, sentence, document,
single-origin, unknown, ambiguity, confusion, error-category, and delta
metrics. It emits no heldout utterance, token text, case identity, timestamp,
path, free-form judgment, or unordered value.

## Acceptance

The heldout comparison has no improvement threshold. Requiring a favorable
heldout result would make final evaluation influence model selection. Success
requires deterministic, internally reconciled reporting and the frozen
fail-closed behavior. Any observed improvement or regression is evidence, not
permission to tune.

The first complete implementation that passes mandatory gates is frozen.
Optional refinement and a post-candidate final review are omitted under the
user's explicit completion direction.

## Consequences

- Context can remove an admitted lexical candidate but can never create one.
- Insufficient context remains observably ambiguous.
- Unknown words remain unknown even when a heldout oracle labels them.
- Model bytes are small, deterministic, auditable, and offline.
- The source portfolio cannot support claims about independent origin,
  natural-language diversity, unseen-word tagging, or general PT-BR accuracy.
- A different feature, scoring rule, source, split, or ambiguity policy
  requires a new version and superseding ADR.

## Alternatives

1. First-order weighted or probabilistic decoding. Rejected because the tiny
   templatic source does not justify smoothing or winner selection and a
   presence rule is sufficient for P08.
2. Choose the first lexical analysis. Rejected because package order is not
   linguistic evidence and destroys P07 ambiguity.
3. Memorize token position, sentence length, surface, or case identity.
   Rejected because it can replay the four templates without contextual
   inference and creates direct leakage risk.
4. Tag unknowns from neighboring context. Rejected because no admitted lexical
   evidence supplies the missing POS fact.
5. Require heldout improvement. Rejected because it turns final evaluation
   into a tuning signal.

## Rollback

Before acceptance, remove P08-only POS runtime, package, split, trainer,
evaluator, schema, validator, and ADR paths. P07 remains intact. After
acceptance, supersede this ADR and version every affected artifact instead of
rewriting accepted bytes.
