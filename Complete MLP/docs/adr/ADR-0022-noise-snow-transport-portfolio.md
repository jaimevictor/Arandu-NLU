# ADR-0022: Noise and Snow transport portfolio

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P15
- Supersedes: ADR-0021 only for replacement transport selection

## Context

ADR-0021 permanently rejected CPython, OpenSSL, their observed runtimes, and
every projection derived from that portfolio. P13 still needs a standardized
authenticated encrypted channel capability that has a small deterministic
source closure and can be implemented without admitting public-domain-derived
software.

The bounded third replacement pass selected Noise revision 34 with Snow
0.10.0. The exact profile is
`Noise_NNpsk0_25519_ChaChaPoly_BLAKE2s`. Snow is built without default
features and with only `use-chacha20poly1305`, `use-blake2`, and
`use-curve25519`. The conservative lock contains 23 selected external
packages. The isolated capability harness additionally records 21 project-authored,
compile-fail `FIXTURE_TECNICA` entries used only to satisfy Cargo metadata
queries for disabled Snow dependencies. They are not external source,
selected dependencies, or permitted compiled artifacts.

The ChaCha20 0.9.1 archive has one public-domain-derived software path,
`src/backends/neon.rs`. The admitted capability source is an exact projection
that removes only that path. Cargo's `.cargo-ok` marker is absent from the
archive and projection and is not a deletion. `chacha20_force_soft` makes the
retained portable backend mandatory; `curve25519_dalek_backend="serial"`
removes architecture-dependent backend selection.

The Snow archive also bundles the third-party Unlicense Cacophony test corpus
at `tests/vectors/cacophony.txt`. The selected feature set does not enable
Snow's vector tests, and that data is absent from both intended Linux runtime
graphs. The admitted Snow source is an exact projection that removes only
that file, retaining every other path, mode, and byte unchanged.

Poly1305 is forced to its portable software backend. Its admitted capability
source is an exact seven-file projection containing the package manifest,
licenses, README, module boundary, software backend, and library root. Unused
AVX2, autodetection, fuzz, benchmark, and test material is excluded. An exact
selected-source origin-notice inventory binds the retained Poly1305 chain and
typenum's copied `num::pow` implementation to eligible immutable upstream
license evidence.

## Decision

P13 selects this exact portfolio as the sole replacement admission candidate.
Its quarantined bytes may be inspected by the mandatory source reviews and
executed by the isolated offline capability probe. Source admission remains
pending until all five independent source reviewers pass one immutable
baseline. This decision does not admit a product runtime, package, base image,
or enabled companion channel.

The cryptographic contract is fixed as follows:

- use only `Noise_NNpsk0_25519_ChaChaPoly_BLAKE2s` through Snow 0.10.0;
- use the exact feature set, 23-package selected source closure, 21 technical
  resolver fixtures, Snow, ChaCha20, and Poly1305 projections, and forced
  backends recorded in `P13-NOISE-SOURCES.yaml`;
- obtain ephemeral randomness through a project-owned fallible resolver that
  reads Linux `/dev/urandom` and fails state construction when entropy is
  unavailable;
- bind protocol version, epoch, ordered peer roles, connection direction, and
  a fresh connection nonce into the Noise prologue;
- reject a wrong PSK, any prologue-field substitution, handshake tampering,
  transport replay, and entropy failure before application data is accepted;
  and
- perform no custom cryptographic primitive, fallback profile, plaintext
  fallback, algorithm negotiation, or network acquisition at build or
  runtime; and
- build the capability evidence only from private copies of validated source,
  a fresh Cargo home, an enumerated Cargo configuration set, forced encoded
  rustflags, and exact resolved and compiled package graphs.

The source projection is not permission for further source editing. Changing
the profile, Snow version or features, dependency closure, backend selection,
or projection requires a newer ADR and fresh source admission.

ADR-0021 remains fully effective. CPython 3.14.6, OpenSSL 3.6.3, the controlled
build, the Homebrew runtime, and every derived projection remain permanently
rejected and cannot be used as fallback or comparison input.

## P14 Responsibilities

P14 may implement the product channel only after the independent P13 source
reviews pass the same immutable baseline. P14 must then:

- reproduce native offline Linux builds for Home Assistant-supported amd64 and
  aarch64 from the exact source portfolio and admit every selected build,
  runtime, packaging, and base-image input;
- define bounded framing, maximum message sizes, handshake deadlines,
  connection-nonce generation and uniqueness, epoch rollover, sequencing,
  rekeying, orderly shutdown, crash handling, pairing, restart, and revocation;
- prove the prologue contract at both real peer processes and prohibit role or
  direction reflection;
- lock each dedicated peer process's complete address space before it receives
  any persistent pairing or private session secret, fail startup if locking or
  no-dump controls cannot be established, and prevent secrets from swap, core
  dumps, files, backups, logs, diagnostics, and telemetry;
- bound one-time provisioning copies and destroy them best-effort immediately
  after transfer; and
- pass packaged Home Assistant add-on and companion-integration tests on both
  architectures before enabling execution.

P13's macOS capability probe is not a substitute for any of those checks.

## USR-018 Residual Risk

`USR-018` permits one narrow compromise: Snow and its Rust dependencies need
not prove that every transient PSK, handshake key, derived key, stack value,
allocator copy, and register copy is individually locked and immediately
zeroized. The minimum acceptable P14 boundary is process-wide memory locking
before secret receipt, dedicated secret-holding peer processes, no dump or
swap exposure, no persistence or observability path, bounded provisioning
copies, best-effort immediate destruction, and fail-closed startup.

The residual risk is that transient copies inside the locked process may
remain until library state is dropped, stack storage is reused, allocator
storage is overwritten, or the process exits. P14 must measure and report the
actual lifecycle and terminate the dedicated process on revocation or
uncertain cleanup. This exception does not permit unlocked persistent state,
disk persistence, logs, diagnostics, backups, core dumps, swap, or continued
operation after a failed memory-control check.

## Consequences

P13 gains a deterministic, auditable capability candidate without reopening
transport comparison. Portable software backends trade performance for a
smaller eligible source and behavior surface. Source use remains quarantined
until independent review passes; product availability remains fail-closed
until P14 completes runtime admission and P15 validates the execution
boundary.

## Rollback

Keep the companion channel disabled, remove the candidate integration, and
retain the local credential-free recognition API. Do not reactivate the
CPython/OpenSSL portfolio. A replacement after this decision requires an
explicit scope decision because the three-pass P13 source-convergence budget
is exhausted.
