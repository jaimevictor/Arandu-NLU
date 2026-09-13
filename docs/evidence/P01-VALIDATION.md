# P01 Validation Evidence

- Phase: `P01`
- Candidate: `eb8e58e92f8ce8896ae81f540de69340c0044630`
- Candidate tree: `9fd1a8bd89416e057a5ae5d2b7b63fec52e6fb41`
- Candidate round: 1 of 3
- Validation time: `2026-08-28T00:44:00Z`
- Reproduction time: `2026-08-28T00:51:23Z`
- Target: `aarch64-apple-darwin`
- Result: `PASS`

## Exact Gate

`tools/validate-p01` ran under its empty-environment Ruby launcher and returned
`P01_GATE_PASS`. The gate verified the Rust 1.98.0 executable hashes, the
11-package lockfile closure, 474 upstream package-file hashes, 11 package
archive hashes, all retained license hashes, distribution coverage, core and
protocol source boundaries, and both versioned schemas. It then executed:

1. `cargo fmt --all -- --check`
2. `cargo clippy --workspace --all-targets --all-features -- -D warnings`
3. `cargo test --workspace --all-features`
4. `cargo build --workspace --all-targets --all-features`

The selected Cargo and Rust tools came from `.tools/rust-1.98.0`; Cargo was
offline, locale and timezone were fixed, incremental compilation was disabled,
and `SOURCE_DATE_EPOCH=0`.

The test command passed 45 tests: 19 core unit tests, 5 core integration tests,
8 protocol unit tests, 3 schema/fixture tests, and 10 wire integration tests.
There were no ignored or failed tests.

`tools/test-validate-p01` returned `P01_GATE_TESTS_PASS` for four mutation
tests covering lock parsing, vendored-file hash mutation, source-boundary
rejection, and distribution path/prefix matching.

## Contract Coverage

The executed tests cover original UTF-8 byte preservation; source-bound,
half-open byte spans; opaque namespaced identifiers; fixed-point confidence;
bounded deterministic hypotheses; all typed slot values; entity generations;
ordered plan nodes and typed relations; graph duplicates, dangling edges,
self-edges, cycles, and stale entities; clarifications; abstentions; injected
logical time and invocation IDs; and exactly four wire outcomes.

Boundary tests exercise N and N+1 for request bytes, identifier bytes,
hypotheses, nodes, relations, slots, evidence spans, clarification options,
aggregate collection items, wire bytes, decoded strings, nesting depth, and
structural items. Hostile wire tests cover malformed UTF-8, duplicate literal
and escaped keys, unknown and missing fields, trailing values, a BOM,
non-integer numbers, overlong numbers, unsupported versions, unknown tags,
invalid identifiers and spans, empty plans, and bounded leak-free errors.

Canonical snapshots cover the request and all four response tags. Schema tests
bind the draft, schema ID, protocol version, strict-object policy, limits,
fixtures, and implementation bytes.

## Dependency And Advisory Evidence

`docs/evidence/P01-DEPENDENCIES.yaml` records every direct and transitive
package, owner, immutable package and VCS identity, purpose, full license
texts, rights, obligations, and supply-chain disposition. `nlu-core` has no
external dependency; only `protocol` reaches the vendored closure.

The independently owned RustSec database at commit
`6420e39260b3d771b049954cf5d52b57e2118da4` was admitted for validation.
Its 1,206 advisory records contained no package name matching the locked
closure. The exact query and limitations are in
`docs/evidence/P01-ADVISORIES.md`.

## Source And Ambient-State Audits

The gate rejected ambient environment, filesystem, network, wall-time,
entropy, unordered-collection, global-mutable-state, and serialization
dependencies from core source. It rejected arbitrary JSON values, floats,
unordered mappings, network/process APIs, and authority-bearing terms from
protocol source. Product tests contain only labeled non-language
`FIXTURE_TECNICA` material.

Semantic types contain no timestamp, path, random identifier, locale value,
credential, raw Home Assistant service, arbitrary JSON payload, callback,
transport, framing, authentication, policy, execution, or response-rendering
authority.

## Failure And Resumption

The initial bundled-linker invocation failed first because its packaged
`libLLVM.dylib` path was not supplied and then because Rust used
compiler-driver arguments. The resumption supplied the bundled library,
selected `linker-flavor=ld`, and fixed `SDKROOT`; the full gate passed. This was
classified as an environment/tool invocation defect.

One protocol compile attempt used a conditionally constant comparison not
supported by Rust 1.98.0; removing the unnecessary `const` qualifier resolved
it. One preflight test exceeded the outer wire limit before its intended string
limit; the fixture was corrected to isolate the intended boundary. The
sanitized Ruby runtime excluded the default-gem test framework, so the P01
validator tests use a standard-library-only assertion runner. All resumed
checks passed.

## Reproducibility Result

Two fresh `--no-hardlinks` clones at distinct absolute paths checked out the
exact candidate commit above in detached mode. Both clean worktrees resolved
to the recorded tree. Each clone mounted the same admitted ignored Rust
toolchain, while Cargo and rustc were invoked through the original absolute
tool paths. The accepted roots were
`/private/tmp/nlu-p01-pass-a.boo5UG` and
`/private/tmp/nlu-p01-pass-b.nvYeJW`.

The accepted builds used an empty environment with `HOME=/var/empty`,
`LC_ALL=C`, `LANG=C`, `TZ=UTC`, `SOURCE_DATE_EPOCH=0`,
`CARGO_NET_OFFLINE=true`, `CARGO_INCREMENTAL=0`, the fixed macOS 26.5 SDK,
the admitted `ld64.lld`, release mode, all workspace features, the exact
lockfile, and offline vendoring. `RUSTFLAGS` selected
`-C linker-flavor=ld` and remapped each distinct clone root to `/workspace`.
With `<root>` set to the applicable accepted root, the command was:

```text
env -i HOME=/var/empty PATH=<admitted-tool-bin>:/usr/bin:/bin LC_ALL=C LANG=C TZ=UTC SOURCE_DATE_EPOCH=0 CARGO_NET_OFFLINE=true CARGO_INCREMENTAL=0 CARGO_TARGET_DIR=<root>/target/p01-repro RUSTC=<admitted-rustc> RUSTFMT=<admitted-rustfmt> DYLD_LIBRARY_PATH=<admitted-tool-lib> SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk RUSTFLAGS="-C linker-flavor=ld --remap-path-prefix=<root>=/workspace" <admitted-cargo> --config target.aarch64-apple-darwin.linker="<admitted-ld64.lld>" build --workspace --all-features --release --locked --offline
```

The native target was the admitted `aarch64-apple-darwin` target already used
by the exact gate. Root A completed in 7.23 seconds and root B in 5.68 seconds.
The selected relative inventory and SHA-256 values were identical:

| Relative path | SHA-256 |
| --- | --- |
| `target/p01-repro/release/libnlu_core.rlib` | `353670015610f1f46bcf9c597f4de16eaa278451741bd6dcdc19e31c16a25a2e` |
| `target/p01-repro/release/libprotocol.rlib` | `43c743fc8a323f55d539e146c2b0dc9d5b331328ec8495359b21fa4c116e8296` |
| `crates/protocol/tests/fixtures/FIXTURE_TECNICA_request-v1.json` | `f917a791d68e59704ccbbf4da4121748fe36e325743e5ef367547217a51e2d17` |
| `crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-abstention-v1.json` | `5099b10ea68d3a931e220a5ef2db560e17272129f3ada44349ee8a50abc33cad` |
| `crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-clarification-v1.json` | `4d523580b4e177871d69f0ff28d4e873ae1a6401c69d01bed9fbf32505b7d4c6` |
| `crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-plan-v1.json` | `0bb6bd07357cec66db156042194e667d59f83b5469013835a0cd97a715637572` |
| `crates/protocol/tests/fixtures/FIXTURE_TECNICA_response-protocol-error-v1.json` | `541511bdf75add75af3a5c0ae3eeb7d1aaeba2aebff8bf8d56c30a4ad362d4e2` |
| `schemas/protocol-v1-request.schema.json` | `5d6c8574c57ac9a8df4c1a3aec7e023d794be1c61b3aa9d8e82810e39d5e5231` |
| `schemas/protocol-v1-response.schema.json` | `6d45b099513cf1b57d42fc5f71e1a942fe56149fc7fac3cf6293829f5cd8c644` |

Earlier setup attempts are not reproduction evidence. Cargo first rejected an
unsupported inline-table command-line override before compilation. A later
explicit `--target` attempt split target flags from native build-script flags,
so build scripts supplied compiler-driver arguments to `ld64.lld`. No tracked
byte or candidate changed. The accepted result came from two newly created
clean roots using the native form of the same recorded target.

## Review Direction

The user explicitly directed the executor to skip the final review and move on
after this run succeeds. No independent post-phase PASS report is fabricated.
The candidate remains immutable, the review waiver is recorded, and the
executor retains responsibility for the gate and checkpoint decision.
