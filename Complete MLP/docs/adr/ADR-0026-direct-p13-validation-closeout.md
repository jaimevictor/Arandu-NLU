# ADR-0026: Direct P13 validation closeout

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0025 for the P13 executable path, acquisition replay
  completeness, origin-inventory version, and private-source parent binding

## Context

Five independent source reviews of the frozen `USR-025` subject
`2870a1bf806f9e2b046af22f2c286a400ee8910d` reproduced four blocker classes:

1. the selected Cargo executable at SHA-256
   `1de2e84c15443b70444eecfa959ff9099dd8c1a5606b6d9ef5bc0ea9c25bc7f9`
   statically retained AES and SipHash bytes from the permanently rejected
   OpenSSL 3.6.3 transport portfolio;
2. the source-origin vocabulary omitted concrete retained statements in
   ChaCha20, Curve25519-dalek, Snow, and Zeroize source;
3. the acquisition recipe did not provide deterministic directory creation,
   exact crate extraction replay, or committed fetcher tests; and
4. private-tree identity stopped at the compiled source root, so a same-user
   process could rename that root, substitute a byte-identical tree, and
   restore the original root without changing any identity inside it.

The selected Noise profile, package versions, projected source bytes,
project-authored Poly1305 implementation, probe behavior, and product boundary
were not rejected.

Review of the first direct-driver subject
`4c75002728e4c84b28d304dc8fc3707446b16262` then reproduced only bounded
validation defects: unadmitted `true`/`false` test executables, stale Cargo
probe fields, a mutable ancestor above the bound source container, a
Cargo-capable aggregate invocation, omitted `librustc_driver` identity, and
unbound preexisting generated artifacts.

## Decision

Apply one blocker-only correction under `USR-026`:

- P13 MUST NOT execute Cargo. The exact Cargo binary and rejection reason remain
  recorded, with disposition `NOT_EXECUTED_BY_P13_NOISE_VALIDATION`.
- A project-authored Ruby driver invokes the admitted `rustc`,
  `clippy-driver`, `ld64.lld`, and `libLLVM.dylib` directly over one fixed,
  topologically ordered 19-crate plan. It builds one `rlib` per crate, compiles
  and executes the probe tests, and runs strict probe Clippy. Build scripts,
  Cargo configuration, Cargo metadata, and network access are absent.
- The frozen prior Cargo target graphs remain source-selection support only.
  P13 does not reexecute or elevate them to product admission. P14 MUST derive
  native amd64 and aarch64 reachability from builds in a kernel-enforced
  read-only source snapshot before admitting product runtime or packages.
- Every compiler, test, and Clippy process is bracketed by exact source checks.
  Identity covers every lexical and resolved ancestor from the filesystem root
  through the private workspace, every source path, each direct executable and
  runtime library, the output-root parent, and every generated artifact that
  exists before the command. Rename/substitute/restore or in-place restoration
  changes an unforgeable identity field.
- The direct tool set is exactly `rustc`, `clippy-driver`, `ld64.lld`,
  `libLLVM.dylib`, and `librustc_driver`; exact byte counts and SHA-256 values
  are evidence-bound. Host dynamic libraries remain ambient host components.
- P13 aggregate and closeout validation require explicit `--no-cargo`; the
  former Cargo execution helper fails unconditionally.
- Driver tests use admitted `/usr/bin/ruby` for controlled success and failure.
  Probe evidence names direct test-harness and direct Clippy execution, not
  Cargo.
- The acquisition tool MUST create private destination directories
  deterministically, publish downloads without clobbering, replay exact crate
  extraction with safe path/type/checksum checks, and have committed
  network-free mutation tests.
- The origin scanner advances only enough to inventory the concrete retained
  statements reproduced by review. Every added row MUST bind exact bytes and a
  rights or non-copy witness. This is not a general natural-language claim.

The correction changes no product crate, protocol, package identity, external
implementation byte, linguistic input, or user-visible behavior.

## Minimum Acceptance

The first frozen replacement is acceptable only when:

- both offline and runtime P13 gates pass;
- direct-driver, acquisition, verifier, and P13 mutation suites pass;
- the four reproduced counterexamples fail closed;
- the six direct-driver review counterexamples fail closed;
- all five independent source reviews and all required P13 phase reviews pass
  the same immutable subject; and
- the checkpoint records exact commit, tree, and archive identities.

No optional final review or refinement follows. On PASS, P13 checkpoints and
P14 starts immediately.

## Consequences

P13's active capability proof no longer imports Cargo's rejected executable
bytes. The selected cryptographic source and behavioral probe remain unchanged.
Native Linux and Home Assistant admission remain P14 responsibilities.

## Rollback

Keep the companion channel disabled and the credential-free local API active.
Do not restore Cargo to P13 validation and do not admit transport runtime until
P14 satisfies the native read-only-snapshot gates.
