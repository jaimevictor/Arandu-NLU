# ADR-0009: Deterministic data pipeline and package format

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-28
- Owners: P03, P06, P15

## Context

P03 must turn an admitted or explicitly authorized source package into
verified, normalized, split, and compiled data without adding language
behavior or weakening provenance. The only current linguistic package is the
P02 `PROJECT_AUTHORED_SYNTHETIC` corpus. It is local, versioned, Apache-2.0,
and limited to internal conformance; it has no external upstream acquisition.

The pipeline must remain offline by default, fail before promotion on any
identity or license defect, preserve source IDs through every derivative, and
produce identical bytes independently of filesystem and record order.

## Decision

Add a Rust workspace package named `nlu-data` with a reusable library and a
thin binary of the same name. It uses only the standard library and the
already admitted Serde and Serde JSON closure.

The binary exposes `fetch`, `verify`, `import`, `normalize`, `validate`,
`split`, `compile`, and `remove-source`. `fetch` requires an explicit
`--allow-fetch` flag and currently supports only a caller-supplied local root;
the package contains no network client and no build script invokes it.

Source manifests are strict versioned JSON. The project-authored variant
records repository-local source and license locators and explicit
project-authored/user-waived dispositions where external upstream evidence or
independent source-review identities do not exist. Missing fields, invented
upstream facts, and promotion to `ADMITTED_AUTONOMOUS` are rejected.

Every stage is immutable and written to a new destination through a sibling
temporary directory followed by rename. Inputs are regular non-symlink files
under a declared root. Import first verifies every listed path, byte size,
SHA-256, record count, license, admission state, and aggregate source digest,
then uses those same verified bytes.

JSONL records are parsed with duplicate-key rejection and bounded size,
nesting, and count limits. Canonicalization recursively sorts object keys while
preserving string bytes. Records retain source ID, artifact path, stable record
identity, and the complete source object.

Split assignment uses the frozen record split and family. One family cannot
cross train, development, held-out, or performance. Ancillary and fail-closed
records receive stable non-scored partitions.

The compiled `nlu-data-package-v1` format is:

1. fixed bytes `NLUDATA`, NUL, and version byte `1`;
2. an unsigned 64-bit big-endian record count;
3. canonical records sorted by source, partition, artifact, and identity;
4. for each record, an unsigned 32-bit big-endian byte length and those bytes.

A strict JSON package manifest records format, source-manifest hash, input
record hash, package hash and size, record count, sorted source IDs, and
partition counts. No product artifact contains a timestamp, absolute path,
host value, locale-derived value, random identifier, or unordered mapping.

`remove-source` filters one source ID from a stage. Recompilation from that
stage must contain no direct or derivative record for the removed source.

## Alternatives

1. Extend the P02 Ruby generator. Rejected because later Rust phases need a
   real workspace data component with reusable validation contracts.
2. Add URL, archive, schema, and cryptographic dependencies. Rejected because
   no external payload is admitted and the existing dependency surface plus a
   small tested SHA-256 integrity implementation is sufficient.
3. Compile source JSONL verbatim. Rejected because object-key and record order
   would remain observable.
4. Use a general opaque serializer. Rejected because a small length-delimited
   package is easier to audit, bound, and reproduce.

## Consequences

- P03 does not fetch from the network; a future external transport requires a
  separately admitted dependency and ADR amendment.
- The package is intentionally simple and uncompressed.
- Runtime loading and linguistic interpretation remain later-phase work.
- A source or oracle defect requires a new source version and pipeline replay;
  compiled output is never repaired in place.

## Rollback

Remove `nlu-data` and every derivative package. Do not retain compiled output
without its verified source manifest and source-ID lineage.
