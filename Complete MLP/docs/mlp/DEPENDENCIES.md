# Active dependencies

The active Rust engine has three direct dependencies and eleven transitive
packages. Exact versions and checksums are fixed by both `Cargo.lock` and
`addon/engine/Cargo.lock`; source is vendored under `addon/vendor`.
`addon/vendor-manifest.json` binds every directory to the checksum of its
exact crates.io archive and to a deterministic extracted-tree digest.
`tools/materialize-mlp-vendor.py` admits only checksum-matching archives,
regular files, and directories, then regenerates Cargo checksum manifests.

| Package | Version | License expression | Purpose |
| --- | --- | --- | --- |
| `serde` | 1.0.228 | MIT OR Apache-2.0 | typed request/response data |
| `serde_core` | 1.0.228 | MIT OR Apache-2.0 | serde runtime |
| `serde_derive` | 1.0.228 | MIT OR Apache-2.0 | deterministic derive macros |
| `serde_json` | 1.0.145 | MIT OR Apache-2.0 | bounded JSON protocol |
| `unicode-normalization` | 0.1.25 | MIT OR Apache-2.0 | PT-BR diacritic normalization |
| `tinyvec` | 1.12.0 | Zlib OR Apache-2.0 OR MIT | Unicode normalization support |
| `tinyvec_macros` | 0.1.1 | MIT OR Apache-2.0 OR Zlib | tinyvec macros |
| `proc-macro2` | 1.0.107 | MIT OR Apache-2.0 | derive macro support |
| `quote` | 1.0.47 | MIT OR Apache-2.0 | derive macro support |
| `syn` | 2.0.119 | MIT OR Apache-2.0 | derive macro parsing |
| `unicode-ident` | 1.0.24 | (MIT OR Apache-2.0) AND Unicode-3.0 | Rust identifier parsing |
| `itoa` | 1.0.18 | MIT OR Apache-2.0 | JSON integer formatting |
| `ryu` | 1.0.23 | Apache-2.0 OR BSL-1.0 | JSON float formatting |
| `memchr` | 2.8.3 | Unlicense OR MIT | JSON byte scanning |

All listed expressions contain an OSI-approved distribution option. Upstream
license files and Cargo checksum manifests are retained with every vendored
package.

The container build uses the official Rust 1.98 Alpine builder image pinned by
OCI index digest. The recorded amd64 and aarch64 manifest digests are in
`addon/container-inputs.json`. The runtime stage is `scratch`: it contains
only the engine binary and its license bundle. The Home Assistant companion
has no Python package requirements beyond Home Assistant itself.
