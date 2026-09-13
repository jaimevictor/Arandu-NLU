# Open Source and Data Provenance Policy

## Admission states

- `SEED_USER_SPECIFICATION`: local/historical requirements only, never
  distributed project material or language data.
- `OPEN_REFERENCE`: openly licensed public contract/source research; no
  payload copied without separate dependency admission.
- `EXTERNAL_CLAIM_ONLY`: bibliographic facts or comparison claims only; no
  implementation, code, data, or oracle use.
- `EXPOSURE_REJECTED`: inspected only far enough to reject; no future use is
  allowed.
- `QUARANTINED_CANDIDATE`: downloaded for review and unusable by build/runtime.
- `ADMITTED_AUTONOMOUS`: all source reviews passed and intended use is allowed.
- `PROJECT_AUTHORED_SYNTHETIC`: Apache-2.0 project-authored linguistic
  conformance material generated from a versioned pre-engine specification
  under `USR-016`; it is not an independently admitted external source.
- `REJECTED`: unusable; reason and removal evidence retained.

Only `ADMITTED_AUTONOMOUS` or `PROJECT_AUTHORED_SYNTHETIC` material may
influence runtime language behavior, training, evaluation, compiled packages,
or shipped artifacts.
`OPEN_REFERENCE` may define a public interoperability contract.
`EXTERNAL_CLAIM_ONLY` may define an independently tested comparison threshold.
`QUARANTINED_CANDIDATE` may be inspected only for its named admission decision;
its `allowed_use` cannot name runtime, training, evaluation, linguistic,
dependency, package, build-input, or shipped use.
`PROJECT_AUTHORED_SYNTHETIC` may influence only the declared internal
conformance, deterministic language-package, and implementation use recorded
by its manifest. It cannot support an independent accuracy, human-language
quality, representativeness, or third-party product-equivalence claim.
`EXPOSURE_REJECTED` and `REJECTED` permit no allowed-use field other than
`none`.

During P00, the complete material and validation-tool ledgers are locked to
canonical digests embedded in the governance validator. A new record, changed
provider, changed owner, changed URL, or changed allowed use requires a new
reviewed candidate; an automated denylist is defense in depth, not source
admission.

P00 repository references also use an exact approved-owner set derived from
those locked ledgers. Alternate GitHub download/API hosts and decoded owner
spellings resolve to the same owner identity. An unfamiliar owner is rejected
until independent ownership and source admission are recorded; a name that
does not contain a vendor keyword is not proof of independence.

## Required evidence

Every candidate proposed for `ADMITTED_AUTONOMOUS`, and every executable
selected for project validation, build, test, package, or runtime use, needs:

- canonical public URL and upstream repository owner;
- immutable commit/tag plus exact admitted paths and artifact SHA-256;
- actual copyright/rightsholders, not only repository maintainers;
- complete license text and hash at that revision;
- proof that the license covers the underlying content, not merely wrappers,
  importers, annotations, or metadata;
- software/data/database license classification and all attribution,
  notice, share-alike, source, patent, trademark, and privacy obligations;
- intended use and whether modification and commercial redistribution are
  allowed;
- acquisition, extraction, normalization, split, compile, and removal recipes;
- transformation lineage and output/derivative licensing;
- per-entry provenance when sources are merged;
- independent discovery, license, provenance, quality, and adversarial reviews.

An `OPEN_REFERENCE` that is used only to define a public interoperability
contract records the canonical owner, immutable revision, complete license,
license hash, and exact inspected contract paths with hashes. It is not a data
or dependency admission and cannot contribute uncited repository content.
`EXTERNAL_CLAIM_ONLY` records immutable response identities where available but
does not acquire implementation rights.

A mutable branch, web page without a versioned artifact, repository-level
license that excludes bundled content, unknown uploader authority, generated
scrape, or unclear output rights fails admission.

Mutable public claim pages may support only factual comparison claims. Their
retrieval date, exact response byte size, and SHA-256 are recorded, while page
content is not redistributed without an eligible license.

Amazon-specific and Amazon-internal projects are ineligible regardless of
license, including AWS/Amazon repositories, SDKs, packages, datasets, models,
services, and documentation.

## License rule

Software must use an OSI-approved license. Data/content must permit use,
modification, and redistribution, including commercial use. Compatible
attribution and share-alike terms require segregation and an explicit
compatibility ADR. Non-commercial, no-derivatives, research/evaluation-only,
source-available, field-of-use, account-bound, or ambiguous terms are rejected.

Project-authored code is Apache-2.0. Third-party data retains its upstream
license; no project notice may imply relicensing. Project-authored
documentation, scripts, schemas, tests, and configuration are also Apache-2.0.
The `PROJECT_AUTHORED_SYNTHETIC` corpus, its generator specifications, and its
generated outputs are Apache-2.0 project-authored material.
Every distributed path must match
`docs/clean-room/DISTRIBUTION-LICENSES.yaml`.

## Linguistic lineage

Each real linguistic entry must resolve to an admitted source ID, upstream
record locator, transformation version, and split assignment. Conflicts retain
all contributing provenances. Unknown forms remain unknown.

Each `PROJECT_AUTHORED_SYNTHETIC` entry instead resolves to its corpus version,
generator version, template family, ordered generation parameters,
pre-engine semantic specification, canonical semantic identity, split, and
output hash. It must never be represented as externally sourced or
human-validated.

No AI output may correct, translate, fill, annotate, validate, or extend an
external linguistic source. Outside `PROJECT_AUTHORED_SYNTHETIC`, AI-generated
language remains prohibited. Automated transformations must be deterministic,
language-agnostic where possible, versioned, and reversible.

The project's own NLU output cannot establish, correct, select, or validate a
gold label, expected semantic outcome, or evaluation judgment. For
`PROJECT_AUTHORED_SYNTHETIC`, the versioned generator specification is the
internal conformance oracle only because it predates NLU implementation and
constructs the utterance and typed expectation together. This does not make
the oracle independent.

Splits are frozen before use and grouped by source, family, document, speaker,
or other leakage boundary appropriate to the dataset. Final held-out data is
not used for rule design, thresholds, model selection, or error-specific
tuning.

## Project-authored synthetic evidence

Before generation, the corpus manifest records:

- the `USR-016` authorization and internal-conformance-only claim boundary;
- the Apache-2.0 owner and license;
- the immutable generator and schema versions;
- the complete intent, domain, slot, graph, outcome, ambiguity, noise, risk,
  contradiction, stale-state, and negative taxonomies;
- template-family definitions and deterministic parameter domains;
- the rule that expected semantics are constructed before and independently
  of NLU execution;
- split, quota, weighting, duplicate, freeze, regeneration, and removal rules;
- exact generated path sizes and SHA-256 values.

The validator must reject unknown generator versions, missing lineage,
duplicate text or semantic identities, cross-split families, underfilled
strata, NLU-derived labels, post-freeze mutation, and any external-accuracy or
equivalence claim based on this corpus.

## Required negative policy tests

P03 admission tooling must reject:

- a licensed importer around an unlicensed corpus;
- a mutable branch or tag without immutable commit verification;
- a CC-BY-NC, CC-BY-ND, research-only, or no-license artifact;
- a repository whose license applies to code but excludes data;
- a source with no rights-holder evidence;
- a hash mismatch, path-scope mismatch, or missing full license;
- a derived artifact lacking per-entry lineage;
- an AI-origin item outside the exact `PROJECT_AUTHORED_SYNTHETIC` exception,
  or any `FIXTURE_TECNICA` item, proposed for linguistic use;
- incompatible share-alike outputs merged into the Apache code artifact.
