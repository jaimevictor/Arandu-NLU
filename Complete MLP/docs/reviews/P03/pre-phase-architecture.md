# P03 Pre-phase Architecture Analysis

- Role: `executor-architecture-synthesis`
- Analysis instance: `p03-executor-architecture-20260828`
- Input baseline: `fb1d88b`
- Mode: read-only repository analysis
- Independence: `PENDING_ELIGIBLE_REVIEWER`
- Result: `PROVISIONAL_ANALYSIS_COMPLETE`

## Selected Structure

Add one non-placeholder Rust package, `crates/nlu-data`, with a reusable
library and the `nlu-data` binary. It uses the existing exact Serde and
Serde JSON dependency closure and the standard library. It introduces no
network library, parser runtime, compression format, or process invocation.

The package owns:

- strict versioned source and stage manifest DTOs;
- bounded regular-file and UTF-8 JSONL readers;
- a tested deterministic SHA-256 implementation for artifact integrity;
- canonical JSON serialization with recursively sorted object keys;
- source verification, import, normalization, split, compilation, and
  source-ID removal functions;
- a thin CLI exposing every required command.

An accepted ADR will record the package format and command boundary before the
candidate freeze.

## Stage Contract

The source manifest is strict JSON. It identifies the source, admission state,
authorization, owner, source locator, immutable version, license and license
hash, redistribution terms, recipes, review dispositions, split policy,
provenance schema, and every artifact path, size, SHA-256, and role.

`PROJECT_AUTHORED_SYNTHETIC` is a distinct manifest variant. It records
repository-local source and license locators plus explicit
`not_applicable_project_authored` dispositions for external owner,
acquisition, and independent-source reviews. It must carry `USR-016` and
`internal_conformance_only`; it cannot use `ADMITTED_AUTONOMOUS`.

The stages are:

1. `fetch`: requires `--allow-fetch` and copies only manifest-listed regular
   files from an explicit local source root to a new snapshot root;
2. `verify`: checks the strict manifest and every input byte without writing;
3. `import`: verifies first, then writes a canonical imported record stream;
4. `normalize`: parses and canonicalizes each record while preserving strings;
5. `validate`: checks stage lineage, provenance, origin, uniqueness, and
   bounded structure;
6. `split`: groups canonical records by frozen split and rejects family
   leakage;
7. `compile`: sorts records by stable identity and emits one versioned,
   length-delimited package plus a hash manifest;
8. `remove-source`: filters all direct and derived records for one source and
   proves none remain.

Every stage writes to a new output path and uses temporary files plus rename so
failure cannot bless partial output. Observable collections are sorted.
Diagnostics report paths and counts only, never utterances or expected
outcomes.

## Reproducibility Envelope

Inputs are source manifest bytes and listed artifacts. Tools are the pinned
Rust toolchain and locked dependency closure. Arguments include source ID,
stage, and output path, but serialized products contain no absolute path,
timestamp, locale, timezone, user, random ID, or filesystem order.

Two clean roots receive the same manifest and source bytes in different
enumeration orders. Their normalized records, split inventories, compiled
package, and package manifest must match byte for byte.

## Alternatives

1. Extend the P02 Ruby generator into an importer. Rejected because P03
   explicitly requires a workspace data component consumed by later Rust
   phases.
2. Add a general archive, URL, and JSON Schema dependency stack. Rejected
   because no external source is admitted and minimum acceptance needs no
   network or archive transport.
3. Compile the source JSONL files verbatim. Rejected because input record order
   and object key order would remain observable.
4. Use an opaque binary serializer. Rejected because the package needs a
   small, auditable, versioned format with deterministic framing.

## Counterexample

Sorting files but preserving JSON object insertion order is not byte-stable
compilation. Two semantically equal records with permuted keys would produce
different package bytes. Canonicalization must recurse through every object
before stable record sorting and framing.

Evidence inspected: P03 requirements, P02 schemas/generator/validator,
`Cargo.toml`, `.cargo/config.toml`, `Cargo.lock`,
`docs/clean-room/SOURCE-POLICY.md`, and ADR-0008.
