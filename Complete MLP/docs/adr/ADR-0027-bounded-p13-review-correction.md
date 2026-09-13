# ADR-0027: Bounded P13 review correction

- Status: `ACCEPTED_AUTONOMOUS`
- Date: 2026-08-29
- Owners: P13-P14
- Supersedes: ADR-0026 only for the final P13 correction details

## Context

Independent review of subject
`56c66e5303a329ae7f19e485d05f179bdcb8c59a` reproduced six bounded blocker
classes: generated outputs were not continuously or initially authenticated;
the active Rust target sysroot was not command-window bound; inherited P07 and
P09 work still reached Cargo; Noise and Cacophony primary Git objects were not
required; the modified Poly1305 manifest lacked its Apache-2.0 change notice;
and complete Rust/Clippy notices and rightsholders were not bound.

## Decision

Apply one correction baseline under `USR-028`:

- bind every generated rlib, probe executable, and Clippy artifact to a
  twice-reproduced exact path, size, and SHA-256 before it becomes trusted;
- retain each post-command output identity through the next command and final
  validation, with the complete output directory layout created before the
  guard starts;
- bind the exact 59-file `aarch64-apple-darwin` target sysroot manifest around
  every direct compiler, test, and Clippy process;
- make `--no-cargo` disable P07 evaluation and P09 reproduction and also route
  the P13 aggregate with explicit no-evaluator/no-reproduction arguments;
- require the exact Noise and Cacophony commit, tree, path, blob, size, and
  SHA-256 from offline primary Git repositories, and require the Cacophony
  object to equal Snow's removed vector bytes;
- require Noise's complete Git tuple to match field-for-field across the
  material and source ledgers, and remove obsolete local projection paths now
  that every active source tree is reconstructed privately from exact archives;
- add a file-local change notice to the projected Poly1305 `Cargo.toml`; and
- bind complete Rust toolchain, standard-library, and Clippy notice files,
  rightsholders, scope, and redistribution obligations.

This changes no package identity, cryptographic implementation byte, protocol,
product behavior, or linguistic input. P13 remains capability-only; native
Linux product admission remains P14 work.

## Minimum Acceptance And Pass Limit

This is the only correction pass for the identified subject. It is minimally
acceptable only when focused mutation suites, offline validation, runtime
validation, and the Cargo-free P13 aggregate all pass; one immutable replacement
then receives the five source reviews and seven phase reviews required by
ADR-0026. The first passing subject checkpoints immediately. No optional
refinement or final-review pass is permitted.

## Consequences

Arbitrary first-creation and inter-command output substitution fail closed,
all active target-library inputs are evidence-bound, primary source identities
are mandatory, and the projected source and toolchain notices satisfy their
recorded redistribution obligations.

## Rollback

Keep the companion transport disabled and retain the credential-free local
server. Do not admit the transport runtime before P14's native read-only build
gates.
