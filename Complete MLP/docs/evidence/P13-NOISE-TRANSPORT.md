# P13 Noise Replacement Transport Evidence

- Phase: `P13`
- Convergence pass: 3 of 3
- Selection: `Noise_NNpsk0_25519_ChaChaPoly_BLAKE2s`
- Implementation: Snow 0.10.0
- Admission scope: quarantined candidate pending five independent source reviews
- Product runtime admission: not granted

## Result

ADR-0022 freezes the replacement transport selection. Source admission remains
pending the five independent reviews named in the manifest. The exact source
manifest, source projection, dependency lock, advisory records, probe, and
immutable verification predicates are in `P13-NOISE-SOURCES.yaml` and
`tools/p13-noise-evidence.rb`. Clean acquisition and offline replay are fixed
by `P13-SOURCE-ACQUISITION.md`.

The portfolio contains 23 selected non-project packages. Snow is selected
without default features and with only ChaCha20-Poly1305, BLAKE2, and
Curve25519. Their 435 archive files are assigned exactly one `RETAIN_EXACT`,
`DELETE_WHOLE_FILE`, `REPLACE_PROJECT_SOURCE`, or
`REPLACE_LICENSE_DECLARATION` action, and two new legal paths have one
`ADD_ORIGIN_NOTICE` action each. The exact admitted P13 projection contains
194 strict UTF-8 files and deletes 243 whole files. It is a conservative
intended-Linux source set, not a native-Linux-proven exact compile union.
Poly1305
`src/backend/soft.rs` is replaced by the project-authored Apache-2.0 software
backend, and its projected `Cargo.toml` license declaration is replaced with
the elected `Apache-2.0` expression. The other 190 retained archive files
remain exact, and the two added files contain the required Rust source notices
and MIT grants. Byte-range edits are prohibited. The verifier binds the action
inventory, retained, added, and deleted paths and trees, and both replacements.

The frozen prior normal-plus-build target observations contain 23 external packages on
`x86_64-unknown-linux-gnu` and 22 on `aarch64-unknown-linux-gnu`;
`cpufeatures` is the sole x86-only package. Seven packages formerly admitted
as resolution-only external source are absent from both selected graphs:
`curve25519-dalek-derive`, `fiat-crypto`, `libc`, `proc-macro2`, `quote`,
`syn`, and `unicode-ident`. They are now represented only by project-authored
compile-fail technical fixtures, so their external archives are not part of
the selected source closure.

The complete lock contains 46 packages: 23 selected external packages, 22
project-authored `FIXTURE_TECNICA` resolver fixtures, and the probe. Archive,
Cargo license expression, and license-file hashes are recorded for every
selected external package. An exact 97-row projected-source origin scan binds
each detected origin statement to its disposition and typed witness. The Snow
0.10.0 archive is 899,770 bytes with SHA-256
`599b506ccc4aff8cf7844bc42cf783009a434c1e26c964432560fb6d6ad02d82`.
The lock also retains target-conditional packages so source resolution is
closed for both intended Linux architectures. Native Linux builds and
Home Assistant packages are intentionally not claimed by P13.

## Standard And Profile

The protocol contract is Noise revision 34 at commit
`ecdf084ece2bf92b16b1201b6ae5c99d23fb4151`, `noise.md` blob
`874aec33e8ee8b431be2733a24b619e863687802`, and SHA-256
`44f249557aa2a21f819ba3dde54a677476d585660036e4a52f83a8a781eddcf6`.
The specification is a non-software technical document placed in the public
domain by its author.

The probe forces `chacha20_force_soft`, `poly1305_force_soft`, and
`curve25519_dalek_backend="serial"`. It supplies a project-owned Snow
`CryptoResolver` whose random source opens `/dev/urandom` and propagates
short-read or unavailable-device failure. Snow's `use-getrandom` feature is
not enabled.

The prologue uses length-delimited fields and binds:

- protocol version;
- epoch;
- ordered initiator and responder roles;
- connection direction; and
- a 32-byte connection nonce.

The connection nonce in the probe is a labeled technical fixture. P14 must
generate a fresh nonce from the admitted resolver and prove lifecycle and
uniqueness at the real peer boundary.

## Probe Coverage

The isolated probe proves:

- successful handshake and encrypted application data in both directions;
- wrong-PSK rejection;
- independent rejection after substituting each prologue field;
- tampered-handshake rejection;
- stateful transport-ciphertext replay rejection; and
- state-construction failure when the entropy device is unavailable; and
- the project Poly1305 backend against an independent 32-bit reference over
  20 project-authored `FIXTURE_TECNICA` cases.

The runtime verifier creates an owner-controlled private directory below the
repository target directory and materializes only the exact 19-package direct
compile plan plus `src/lib.rs` from the probe. A project-authored Ruby driver
invokes the admitted `rustc` directly in topological order, compiles and runs
the probe tests, and invokes `clippy-driver` with warnings denied. Cargo, build
scripts, Cargo metadata, Cargo configuration, and network access are absent
from this active path. Forced backends are fixed in the direct rustc argument
vector.

The source root is read-only and resides below a separate read-only containing
directory. Every lexical and resolved ancestor from the filesystem root through
the private workspace is identity-bound. Device, inode, mode, ownership, link
count, size, nanosecond change time, and regular-file SHA-256 are also bound for
the source tree, output-root parent, all five direct tool/runtime files, the
complete 59-file target sysroot, and every generated artifact. The output
directory layout exists before guarding begins. Each generated rlib, test
binary, and Clippy artifact must match a twice-reproduced exact size and
SHA-256 before it becomes trusted, and its post-command identity remains bound
through the next command and final validation. These checks run before and
after each compiler, test, and Clippy process.

Twenty-two project-authored `FIXTURE_TECNICA` resolver entries explain the
frozen historical Cargo lock resolution for disabled Snow optional and
development dependencies. Their source is a mandatory `compile_error!`; they
carry no external bytes and are neither materialized nor executed by direct
validation. The tracked lock records 23 external packages plus those 22
technical entries and the probe.

Before running tests and strict Clippy, the verifier proves the effective rustc
cfg, exact 19-package topological plan, and private source identity. It binds
`rustc`, `clippy-driver`, `ld64.lld`, `libLLVM.dylib`, and
`librustc_driver-4031c0ff8e88f5d1.dylib` by exact path, size, SHA-256, and
command-window identity. Complete Rust, standard-library, and Clippy notices
and rightsholders are bound separately. The prior 23/22-package Linux graphs remain immutable
source-selection support only and are not reexecuted. P14 must replace that
supporting observation with native read-only-snapshot build evidence.

## Advisory Evidence

The admitted RustSec database is fixed at commit
`6420e39260b3d771b049954cf5d52b57e2118da4` and tree
`01794d45488a521b322b760b6bfdcd6e9f28932b`. The verifier inventories Git
paths only under the literal selected-package directories. That bounded
inventory identifies five recorded paths; the verifier binds their exact blob
identities and reads only those five advisory blobs. Each selected version
meets the patched threshold recorded in its bound advisory:

| Package | Advisory | Selected | Patched |
| --- | --- | --- | --- |
| Snow | `RUSTSEC-2024-0011` | 0.10.0 | >= 0.9.5 |
| Curve25519-dalek | `RUSTSEC-2024-0344` | 4.1.3 | >= 4.1.3 |
| ChaCha20 | `RUSTSEC-2019-0029` | 0.9.1 | >= 0.2.3 |
| BLAKE2 | `RUSTSEC-2019-0019` | 0.10.6 | >= 0.8.1 |
| Generic Array | `RUSTSEC-2020-0146` | 0.14.7 | >= 0.13.3 |

The database root grant names CC-BY-4.0 for explicitly marked imported
records. Its bundled file under that name incorrectly contains CC-BY-SA-4.0
and is rejected as legal terms. The verifier instead binds the official
Creative Commons BY 4.0 legal code at SHA-256
`9ba9550ad48438d0836ddab3da480b3b69ffa0aac7b7878b5a0039e7ab429411`,
and records the root and CC0 license hashes and all 21 explicit CC-BY marks.

This is a selected-directory check of five exact records in one fixed database
snapshot. It is not a whole-database audit or a claim that no undisclosed or
out-of-scope vulnerability exists.

## Boundary And Residual Risk

No transport code is linked into a product crate and no companion channel is
enabled by this evidence. Until all five source reviews pass one immutable
baseline, the portfolio remains a quarantined candidate usable only for
admission review and this isolated non-product probe. P14 owns native
amd64/aarch64 Linux builds, build and base-image admission, framing and limits,
real peer integration, pairing, rekeying, restart and revocation, process-wide
memory locking, no-dump and swap controls, and Home Assistant packaging. P15
owns execution-boundary validation.

P13 does not claim a kernel-enforced read-only snapshot against a privileged
host attacker or native Linux file reachability. P14 must run both native
Linux builds from a kernel-enforced read-only snapshot, derive the actual
target source paths, and reject any projection omission before product
admission.

Under `USR-018`, P14 may report the bounded residual risk that transient
library, stack, allocator, and register copies inside a completely locked
dedicated peer process are not individually proven to be immediately
zeroized. It may not relax process-wide locking, fail-closed startup, dump and
swap exclusion, persistence and backup prohibition, observability exclusion,
bounded provisioning, or process termination on uncertain cleanup.

The CPython/OpenSSL portfolio remains permanently rejected under ADR-0021.
The Rust 1.98.0 Cargo binary at SHA-256 `1de2e84c...25bc7f9` is also excluded
from P13 execution because source review found statically retained bytes from
that rejected portfolio. Nothing in this evidence reopens it.

## Commands

```text
tools/p13-noise-evidence --skip-runtime
tools/p13-noise-evidence
tools/validate-p13 --no-cargo --review-candidate
tools/test-p13-noise-evidence
tools/test-p13-rustc-driver
tools/test-p13-source-fetch
ruby -c tools/p13-source-fetch.rb
ruby -c tools/p13-rustc-driver.rb
ruby -c tools/p13-noise-evidence.rb
ruby -c tools/test-p13-noise-evidence.rb
git diff --check
```
