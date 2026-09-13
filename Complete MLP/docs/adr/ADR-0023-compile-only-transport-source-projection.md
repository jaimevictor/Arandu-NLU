# ADR-0023: Compile-only transport source projection

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P15
- Supersedes: ADR-0022 only for source projection and Poly1305 backend origin

## Context

The `USR-022` candidate retained 414 files from 23 selected external packages.
Independent review found that unrelated tests, vectors, changelogs, examples,
and generated metadata enlarged the admitted rights surface even though Cargo
never compiled them. Review also found that the selected Poly1305 software
file's historical Donna chain did not establish complete immutable grant
authority.

The forced host build and both intended 64-bit Linux dependency graphs need a
192-file union before generated Cargo checksum manifests. That union retains
the package manifest, every applicable license and obligation-bearing notice,
required build scripts, embedded documentation read by `include_str!`, and
every source file reached by the fixed feature and backend configuration. It
contains no binary vector, separate test, benchmark, example, changelog,
crate-local lock, or unused backend file.

Deleting inactive ranges inside otherwise compiled files changed Rust metadata
artifacts even when executable behavior was unchanged. This decision therefore
permits only whole-file projection. Mixed files remain byte-for-byte identical
to their archives and require exact origin disposition.

## Decision

P13 keeps the Noise revision 34, Snow 0.10.0, package versions, lock
resolution, features, forced backends, and protocol behavior selected by
ADR-0022. It changes only the candidate source projection:

- validate each complete immutable crate archive in quarantine;
- retain the exact 192-file host/amd64/aarch64 union recorded by
  `P13-NOISE-SOURCES.yaml` and the verifier;
- assign every archive path exactly one `RETAIN_EXACT`, `DELETE_WHOLE_FILE`,
  or `REPLACE_PROJECT_SOURCE` action and hash both retained and removed trees;
- retain all package legal files and obligation-bearing notices mechanically;
- build all registry packages from private projected directories while keeping
  their exact locked package identities and archive checksums;
- replace only Poly1305 `src/backend/soft.rs` with the project-authored
  Apache-2.0 44/44/42-bit implementation tracked by the capability probe;
- force that backend and reject the original historical-origin file from the
  admitted projection;
- scan every retained regular file as strict UTF-8/no-NUL text or binary,
  bind the complete path partitions, and bind each retained origin statement
  to one immutable disposition and typed witness; and
- inventory RustSec paths only inside literal selected-package directories,
  then read only the exact matching advisory blobs and fixed legal files.

The project-authored Poly1305 source is technical software, not linguistic or
evaluation data. Its arithmetic follows the public Poly1305 definition, uses
no external implementation bytes, and is validated against an independent
32-bit reference using 20 project-authored `FIXTURE_TECNICA` cases plus the
existing authenticated-channel tests. P14 must repeat native Linux validation
before product admission.

Upstream-generated release files that remain in the projection are admitted as
exact archive bytes under their package grants. The project does not execute,
redistribute, or claim reproducibility of an upstream generator unless that
generator is separately selected.

## Consequences

The candidate source surface is smaller and auditable without changing the
resolved dependency graph. Removing whole unreachable files avoids admitting
their data and attribution chains. The custom Poly1305 backend adds a narrow
cryptographic review obligation but removes an external grant that could not
be proven.

This is the terminal P13 blocker correction authorized by `USR-023`. It is not
a general source-editing entitlement and creates no optional refinement pass.

## Rollback

Keep the companion channel disabled and revert to the credential-free local
recognition API. Do not restore the Donna-derived backend, removed package
files, CPython/OpenSSL portfolio, or an alternate transport without a newer
explicit user decision and ADR.
