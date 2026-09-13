# P06 Pre-phase Architecture Analysis

- Role: `independent-architecture-analysis`
- Analysis instance: `01a04ae3-3c98-7f41-9633-53390963687d`
- Input baseline: `901f2665027516c671d372ae1b3d227b49e0092d`
- Input tree: `88b244e990382a53ceebab27330b5ccce00bbad0`
- Mode: read-only repository analysis
- Independence: `INDEPENDENT_READ_ONLY_AGENT`
- Result: `PROVISIONAL_APPROACH_1_SELECTED`

## Selected Structure

Extend the existing `nlu-data` and `lang-ptbr` packages; add no crate and no
new third-party package.

`nlu-data` gains a lexicon module with:

- direct compilation from a separately pinned source manifest and verified
  source bytes, never from a caller-authored intermediate P03 stage;
- strict typed parsing of the one manifest artifact whose role is `lexicon`;
- a pure in-memory transformation from exact source rows to complete
  provenance-bearing entries;
- deterministic binary framing plus a closed canonical sidecar manifest;
- strict decode and validation shared by compilation, removal, and runtime;
- source-ID removal that rebuilds every inventory before atomic promotion.

`lang-ptbr` embeds the checked artifact with `include_bytes!`, asks the
in-memory decoder for a validated package, and builds private `BTreeMap`
indexes. It exposes only shared entry references and no constructor for
caller-supplied linguistic bytes. Lookup does no filesystem, network, locale,
time, or mutable-global work.

The frozen P02 source and source manifest remain byte-identical. A new
accepted ADR must fix this format and component boundary before candidate
freeze.

## Admission Boundary

Compilation first checks an executor-pinned SHA-256 for the complete source
manifest. Existing `verify_source` then checks every declared source artifact,
license, accepted ADR, aggregate byte count, and aggregate hash before P06
reads one lexical row.

P06 additionally pins and cross-checks:

- source manifest SHA-256
  `d9e1ca32ec0f92aa6b5fc6c1d4f232f93389e0bf8031267d23daddf7287006c5`;
- lexicon SHA-256
  `727e89195fc2ed16489c24b17841d58a2a9bb68c828769ece83ab70489316e4e`;
- specification SHA-256
  `f72451f03d1a5e2e4955b5d2857bd7d33b3b012912d920e53a3d85719f14859d`;
- generator SHA-256
  `ff8817afc2c2f13d539ab7d10720cab407d769ca3a6189dcc55d43ea052689d1`;
- Apache-2.0 license SHA-256
  `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4`.

A coordinated rewrite that recomputes caller-controlled manifest hashes must
therefore fail before output creation.

## Artifact Contract

Use `nlu-lexicon-package-v1`:

```text
NLULEX, NUL, version byte 1
unsigned 64-bit big-endian entry count
repeated:
  unsigned 32-bit big-endian canonical-JSON byte count
  exact canonical-JSON entry bytes
```

Entries are sorted by exact surface bytes, lexical category, lemma, feature
list, source ID, and analysis ID. No entry is deduplicated by surface or
semantic payload.

Every closed entry contains:

- the exact original analysis ID, surface, lemma, POS, and sorted features;
- source ID, `PROJECT_AUTHORED_SYNTHETIC` state, corpus version, locale,
  source license, and frozen `shared` partition;
- source-manifest hash, artifact path/hash, stable analysis locator, and exact
  source-row hash;
- generator ID, specification hash, generator implementation hash, generation
  family, ordered generation parameters, and canonical lexical identity hash;
- ordered versioned transform steps with immutable implementation, input, and
  output hashes;
- derivative license `Apache-2.0`.

The canonical sidecar manifest records schema and format versions, package
hash and byte count, entry count, sorted source IDs, and sorted derivative
licenses. It contains no timestamp, absolute path, locale-dependent value, or
random identifier.

Source removal validates the package, rejects an absent source ID, removes
whole entries, and emits a new package and manifest from survivors. It does
not retain a removed source ID or source-specific inventory in the output.

## Runtime API

The minimum public surface is:

```text
Lexicon::bundled() -> Result<Lexicon, LexiconError>
Lexicon::entries() -> &[LexicalAnalysis]
Lexicon::lookup(surface) -> LexicalLookup
Lexicon::analysis(source_id, analysis_id) -> Option<&LexicalAnalysis>
Lexicon::lookup_token(token, normalized_text) -> Result<LexicalLookup, TextError>
```

`LexicalLookup` is closed as `Unknown`, `Unique`, or `Conflict`. `Conflict`
contains every analysis in canonical order. No API selects a preferred
analysis; P07 and P08 own later morphology and contextual disambiguation.

`Lexicon` owns private indexes by exact surface and `(source_id, analysis_id)`.
It returns immutable slices or shared references only. `bundled` returns an
owned immutable index and uses no global cache.

Token lookup uses the exact normalized token slice. It performs no case
folding, accent removal, compatibility normalization, stemming, or fuzzy
matching.

## Fail-Closed Contract

Reject before output promotion or index construction:

- unknown source identity or admission state;
- wrong artifact role, count, path, hash, or license;
- malformed UTF-8/JSON, duplicate or unknown fields, or unbounded values;
- duplicate analysis identities or noncanonical feature/entry order;
- missing, reordered, unknown, or hash-inconsistent lineage;
- missing or substituted source/derivative license;
- bad magic/version/count/length, truncation, or trailing bytes;
- manifest/package count, hash, source, or license disagreement;
- forbidden technical-fixture markers in production entries;
- an absent source removal request.

Diagnostics expose error codes and structural context, not lexical text.

## Tests And Files

Minimum tests cover full 33-entry preservation, complete provenance, the
two-analysis conflict, two clean builds, record permutations, corrupt framing
and metadata, immutable API shape, embedded-versus-fresh byte equality, exact
source removal, selective technical-fixture removal, and no source-ID bytes
after sole-source removal.

Expected implementation paths are:

- `crates/nlu-data/src/lexicon.rs` and existing library/CLI helpers;
- `crates/nlu-data/tests/lexicon_contract.rs`;
- `crates/lang-ptbr/src/lexicon.rs` and existing exports/errors;
- two closed lexicon schemas;
- `data/lexicon/p06/package.bin` and `package-manifest.json`;
- one accepted ADR, P06 validator/evidence, distribution inventory, and
  traceability updates.

## Counterexample

`BTreeMap<surface, analysis>` is deterministic but wrong: inserting the two
source analyses for the repeated surface overwrites one. The index must map
one exact surface to an ordered range containing every analysis.

Evidence inspected: P06 requirements, source policy, ADRs 0001, 0009, 0010,
and 0011, the P02 source manifest and lexicon, current `nlu-data` source and
tests, current `lang-ptbr` source and dependencies, and published data schemas.
