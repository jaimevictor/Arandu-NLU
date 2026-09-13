# ADR-0024: Projected origin-notice closure

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P15
- Supersedes: ADR-0023 only for origin detection, added notices, and license election

## Context

Independent review of the ADR-0023 candidate confirmed the exact 23-package
archive closure, compile-only file projection, project Poly1305 implementation,
advisory inventory, target graphs, and offline probe. It also reproduced two
bounded rights-evidence defects.

The line-local origin matcher omitted wrapped attribution statements. The
projected typenum and generic-array sources identify copied or adapted Rust
implementations but did not carry the corresponding Rust copyright and MIT
notice. The Poly1305 projection combined upstream dual-licensed files with an
Apache-2.0-only project replacement while incorrectly electing MIT for the
combined output.

## Decision

P13 keeps every package identity, dependency edge, feature, backend, compiled
source byte, and protocol behavior selected by ADR-0022 and ADR-0023. It makes
only these source-evidence corrections:

- scan an origin statement using its bounded contiguous comment or text
  paragraph so a trigger and its attribution may span lines;
- bind generic-array's two `rust-lang/rust#49000` statements to the immutable
  public PR head commit, tree, exact adapted source ranges, `COPYRIGHT` blob,
  and complete MIT/Apache grants;
- add one deterministic `LICENSE-RUST-MIT` file to generic-array, formed from
  the exact nine-line Rust source header followed by the exact MIT license;
- add `LICENSE-RUST-NUM-MIT` to typenum, formed from rust-num's exact
  nine-line source header followed by its exact MIT license;
- model both files as `ADD_ORIGIN_NOTICE` projection actions and include them
  in all tree, path, text, source, checksum, and private-materialization
  identities; and
- elect Apache-2.0 for the combined Poly1305 projection because every retained
  upstream byte offers Apache-2.0 and the replacement is Apache-2.0, and
  deterministically replace only the projected `Cargo.toml` license expression
  with `Apache-2.0` so package metadata states that election exactly.

The two added files are legal notices only. Cargo does not compile them. The
manifest replacement changes metadata only, no additional external
implementation is selected, and the existing Poly1305 backend remains the only
compiled-source replacement.

## Consequences

The projected source count increases from 192 to 194 solely through two
obligation-bearing notice files. Wrapped attribution is fail-closed under a
bounded scanner and every detected statement requires a typed witness. The
combined Poly1305 license election and projected package metadata now match all
projected bytes.

This is the blocker-only correction authorized by `USR-024`, not an optional
refinement or a general source-modification entitlement.

## Rollback

Keep the companion channel disabled and retain the credential-free local API.
Do not ship a projection that omits either Rust notice, restores line-local
origin detection, or labels the project Poly1305 replacement as MIT.
