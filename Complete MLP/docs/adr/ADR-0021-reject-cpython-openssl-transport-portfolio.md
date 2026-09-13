# ADR-0021: Reject the CPython and OpenSSL transport portfolio

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0020 for all future product use of the portfolio

## Context

Fresh independent P13 source review found that ADR-0020's two-component
description was incomplete. The controlled CPython build also compiled the
CC0-dedicated `Modules/blake2module.c`, and the controlled OpenSSL build also
compiled public-domain-dedicated `crypto/aes/aes_core.c`. Exact source,
object, installed-artifact, attribution, and license hashes are recorded in
`P13-EXACT-SOURCES.yaml`.

Those paths are rejection witnesses, not a complete license inventory.
Further public-domain-derived paths exist in the complete archives. A
sanitized projection would therefore require another open-ended inventory and
would consume P14 without establishing a small or auditable dependency
surface.

## Decision

The complete CPython 3.14.6 and OpenSSL 3.6.3 source archives, the controlled
build, the Homebrew runtime, and every projection derived from this portfolio
are permanently rejected for product selection, build, runtime, packaging,
distribution, or P14 transport implementation.

P13 may retain the exact quarantined bytes and local probe only as bounded
rejection and capability evidence. The evidence makes no complete bundle
license or rightsholder claim. Its known prohibited-path list is explicitly a
non-exhaustive witness set sufficient to reject the entire portfolio.

P14 must select a different standardized transport from independently
admitted OSI-licensed sources. It may not sanitize, reuse, derive from, or
package this portfolio. Plaintext and project-authored cryptography remain
prohibited.

## Consequences

- P13 closes no transport-admission claim and enables no companion channel.
- The P13 policy, protocol v2, and credential-free local server are unchanged.
- P14 source convergence starts with a replacement portfolio, not another
  CPython/OpenSSL remediation pass.
- A complete inventory of an already rejected archive is unnecessary and
  cannot become an admission shortcut.

## Rollback

Keep companion execution disabled and retain the versioned local recognition
API. This portfolio cannot be reactivated without a newer explicit user
decision and a fresh independently reviewed source admission.
