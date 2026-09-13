# P15 Source Admission Discovery Review

- Role: `source-admission-discovery`
- Analysis instance: `01a08c8d-28a0-79f0-9098-58f45dff73da`
- Subject commit: `7ad4bcb6e568438269a61a9704e669de1bbd3e62`
- Subject tree: `00a1dfe98bed337f9f8b39273fb1e7456365a95e`
- Mode: read-only
- Verdict: `FAIL`

## Finding

No admitted native Linux amd64 or aarch64 executor, Linux compiler target,
linker, CRT/libc closure, kernel-enforced read-only build environment, OCI
executor, real Home Assistant lifecycle environment, or complete Supervisor
runtime exists. The admitted Rust installation is
`aarch64-apple-darwin` only. The available Home Assistant Python environment
is rejected and contains 105 unadmitted distributions.

The companion package also lacks the required executable
`bin/{amd64,aarch64}/companion-helper` payloads, and no OCI artifact, SBOM,
notice bundle, checksum manifest, or release-input inventory exists.

## Portfolio Assessment

The smallest admissible topology is one mode-preserving companion ustar and
two scratch OCI images. Native Rust 1.98 musl toolchains and project-authored
packaging are preferred. A minimal dynamic GNU root filesystem is the only
bounded fallback. Official images plus general container and SBOM stacks are
rejected as a larger unadmitted closure.

## Counterexamples

- A reproducible `linux/arm64` manifest containing Mach-O or x86-64 bytes must
  fail.
- A reproducible companion archive that strips the aarch64 helper executable
  bit must fail.

## Evidence

The review inspected ADR-0039, ADR-0040, ADR-0044, the P13 and P14 source
ledgers, `.cargo/config.toml`, `rust-toolchain.toml`,
`addon/build-contract.json`, `addon/runtime-contract.json`, companion helper
selection, add-on binaries, and available host executables.

Representative commands resolved the exact commit and tree, verified the
clean worktree, inventoried executable availability, and enumerated required
package paths. No write, network, sibling, prohibited-source, or execution
oracle access occurred.
