# ADR-0020: Conditional transport source remediation

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0019 only for P13 product-runtime source admission

## Context

Independent P13 source review reproduced non-OSI CC0 software in both exact
candidate archives. CPython 3.14.6 contains bundled Expat SipHash bytes, and
OpenSSL 3.6.3 incorporates the CC0 reference implementation in
`crypto/siphash/siphash.c`. The controlled build compiled both components.
The complete archives and observed runtimes therefore cannot be admitted as
product inputs under ADR-0001.

The transport probe still establishes a bounded capability fact: CPython
`ssl` backed by OpenSSL can negotiate the selected TLS 1.3 external-PSK
profile and reject the tested downgrades. It does not establish a
distributable runtime.

## Decision

P13 retains the API and protocol portfolio only as conditional capability
evidence. No companion transport is enabled, packaged, or admitted in P13.
This supersedes ADR-0019's requirement that P13 admit the product runtime;
P14 owns product-runtime admission before it may implement or enable the
channel.

P14 may admit this portfolio only from a deterministic sanitized source
projection that:

- excludes every non-OSI source byte before the admitted build input is
  created;
- configures OpenSSL with its documented `no-siphash` option and proves that
  the rejected source is absent from every object, library, and package;
- disables CPython's bundled Expat-dependent modules or uses a separately
  admitted OSI-only dependency, and excludes the rejected bundled bytes;
- records the complete retained-source license and rightsholder closure;
- passes exact source-to-binary, amd64 and aarch64, Home Assistant runtime,
  advisory, transport-profile, and secret-process tests; and
- receives the mandatory independent source and candidate reviews.

If that projection fails within P14's three-pass budget, P14 must reject the
portfolio and select another admitted FOSS transport. Plaintext, custom
cryptography, packaging the complete rejected archives, or treating an
uncompiled prohibited file as an admitted input are not alternatives.

## Consequences

P13 policy, protocol v2, and the credential-free local server can close
without weakening the FOSS boundary. P14 has a concrete first implementation
candidate, but transport and execution remain unavailable until its product
runtime passes admission. The original exact archives remain quarantined
review inputs and are never release contents.

## Rollback

Keep the companion channel disabled and retain local protocol recognition.
Delete any failed sanitized build output and its derived evidence before
trying the next bounded P14 portfolio.
