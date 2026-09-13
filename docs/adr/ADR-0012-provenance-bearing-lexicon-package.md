# ADR-0012: Provenance-bearing lexicon package

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-28
- Owners: P06-P09

## Context

P06 must make exact lexical facts available to the Portuguese runtime without
discarding source conflicts, admitting unreviewed language, or allowing
callers to substitute a linguistic artifact. Every entry must retain enough
immutable lineage to reproduce and remove its contribution.

The only eligible lexical source is the P02
`PROJECT_AUTHORED_SYNTHETIC` corpus authorized by `USR-016`. Its 33 entries
are Apache-2.0 project-authored material for deterministic internal
conformance and language-package use. They are not independent evidence of
Portuguese accuracy or representativeness. Rejected P02 candidates remain
ineligible.

## Decision

Extend `nlu-data` with a direct lexical compiler and strict decoder. The
compiler accepts only the exact source manifest whose SHA-256 is independently
pinned in the implementation. It checks that pin before opening any
manifest-selected artifact, then applies the existing source admission,
license, aggregate, and artifact checks.

Each compiled entry preserves the source analysis ID, surface, lemma, part of
speech, and sorted features byte for byte. It adds the admitted source
identity, corpus and artifact locators, source-row hash, frozen `shared`
partition, generator specification and implementation identities, ordered
generation parameters, canonical semantic identity, ordered transform hashes,
and Apache-2.0 derivative-license identity. The compiler never adds, repairs,
filters, ranks, or selects a linguistic fact.

The `nlu-lexicon-package-v1` framing is:

1. exact bytes `NLULEX`, NUL, and version byte `1`;
2. an unsigned 64-bit big-endian entry count;
3. for each entry, an unsigned 32-bit big-endian byte count followed by one
   canonical JSON entry conforming to `lexicon-entry-v1.schema.json`.

Entries are sorted by exact surface, part of speech, lemma, feature list,
source ID, and analysis ID. Equal surfaces remain separate entries. The
canonical `lexicon-package-manifest-v1` sidecar binds the transform, input and
package hashes, package size, entry count, source inventory, and derivative
license inventory. Neither file contains time, an absolute path, host state,
locale-derived behavior, entropy, or unordered serialization.

Decoding rejects malformed framing, noncanonical or unknown JSON fields,
unsupported values, duplicate identities, noncanonical ordering, incomplete
or substituted lineage, package or inventory disagreement, and resource-limit
violations before returning any entry.

`lang-ptbr` embeds the checked package and sidecar and builds private
`BTreeMap` indexes by exact surface and by `(source_id, analysis_id)`.
`Lexicon::bundled` is the only runtime constructor. Lookups return immutable
shared references as `Unknown`, `Unique`, or `Conflict`; P06 never selects a
winner. Token lookup uses the exact normalized token surface and performs no
case folding, accent removal, stemming, fuzzy matching, filesystem access, or
ambient lookup.

Source removal validates the complete input, rejects an absent source ID,
filters whole entries, rebuilds all inventories, and atomically promotes a
new package. Removing the sole source yields a valid empty package containing
no source-ID bytes. The package-level source-filter transform records the
parent package hash; unchanged surviving entries retain their original
entry-level lineage.

## Consequences

- Runtime lexical coverage is intentionally limited to the 33 frozen P02
  entries.
- Both analyses of an equal source surface remain observable in canonical
  order.
- The compiler and decoder add no third-party dependency.
- A source, generator, compiler, schema, or format change requires a new
  deterministic artifact and review.
- The runtime depends on the reusable strict decoder in `nlu-data`, but does
  not expose compilation or caller-supplied artifact construction.

## Alternatives

1. Search for another external source. Rejected because P02 exhausted the
   bounded source-recovery pass and `USR-016` already authorized the frozen
   project-authored fallback.
2. Map each surface to one preferred analysis. Rejected because insertion
   order would hide the existing source conflict.
3. Read JSONL directly at runtime. Rejected because it would expose mutable
   paths and duplicate admission logic.
4. Compile from a caller-authored P03 stage. Rejected because that stage is
   not a complete per-entry admission or lineage boundary.

## Rollback

Remove the P06 package, schemas, compiler and decoder module, runtime lexicon
module, and this ADR index entry. Do not retain a derivative entry without its
verified P02 source and complete lineage.
