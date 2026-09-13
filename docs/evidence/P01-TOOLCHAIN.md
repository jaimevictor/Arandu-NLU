# P01 Toolchain Admission

- Admission date: 2026-08-27
- Target: `aarch64-apple-darwin`
- Status: `ADMITTED_P01_BUILD_TOOLCHAIN`

## Rust Distribution

The official Rust 1.98.0 channel manifest was downloaded from
`https://static.rust-lang.org/dist/2026-08-20/channel-rust-1.98.0.toml`.
It is 898,637 bytes with SHA-256
`3f7d139b73bbbd0004ef6e58b430831c68cdad2b1f64ee2eb35d54c09199489a`.
The manifest identifies Rust source commit
`88d9e12ae178fab0fb5cc050a94da85685d449ea`.

The complete standalone archive
`rust-1.98.0-aarch64-apple-darwin.tar.xz` has SHA-256
`5395f380bd220890b89b7e8ce137f3965cf0625b6f561af11e97c8d5c8743c3b`,
matching the channel manifest. Only `rustc`,
`rust-std-aarch64-apple-darwin`, `cargo`, `rustfmt-preview`, and
`clippy-preview` were installed under ignored `.tools/rust-1.98.0`.

`/usr/bin/ruby` verified both SHA-256 values. `/usr/bin/tar` extracted the
named component trees. Ruby `FileUtils` copied only paths declared by each
component's `manifest.in`, preserved modes, and rejected differing collisions.
The upstream shell installer and rustup were not executed.

## Executable Identities

| Tool | Version | SHA-256 |
| --- | --- | --- |
| `rustc` | `1.98.0 (88d9e12ae 2026-08-18)` | `a11618eca0956a8aa4372c2bc898690b513cbdfa2cb9125b2a5301e360ed5b49` |
| `cargo` | `1.98.0 (797e8a9bc 2026-08-05)` | `1de2e84c15443b70444eecfa959ff9099dd8c1a5606b6d9ef5bc0ea9c25bc7f9` |
| `rustfmt` | `1.9.0-stable (88d9e12ae1 2026-08-18)` | `ca9cbe15a4add6baf62d8ce177015c9c48f209ebcf4364416b1953142e8701f8` |
| `cargo-clippy` | `0.1.98 (88d9e12ae1 2026-08-18)` | `bf89162b33afa0518da4004ab5f0e13f5b5cd143e6349a1720a003944910837b` |
| `ld64.lld` | Rust 1.98.0 bundled LLVM 22.1.8 | `910ef9bb07e4f137121da153c4267ebc3d3f30f88a9ee1e397f117402ec96640` |

The linker dynamically loads the archive's `lib/libLLVM.dylib`, SHA-256
`6da171ecd17bbe20b57b2e2d2e324b8fb2267117b504e864eb8b3012a71a6fec`.
Builds select `ld64.lld` explicitly with Rust's `linker-flavor=ld` argument
contract and supply that library directory through `DYLD_LIBRARY_PATH`. Host
Apple clang and ld are not selected project tools.

The ambient SDK input is fixed to
`/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk`. Its
`SDKSettings.json` identifies `macosx26.5` and has SHA-256
`f8d005f09381389167f9e0aeaa169bc9e7dff162ef22ca2fd8e98df7ff1acafe`.
Setting `SDKROOT` prevents an implicit `xcrun` lookup. The SDK and dynamic
system libraries remain ambient host inputs and are not shipped dependencies.

## Licenses And Rights

Rust, Cargo, rustfmt, and Clippy are distributed under `MIT OR Apache-2.0`;
the bundled LLVM/linker portions are under Apache-2.0 with the LLVM exception
and other OSI-approved notices included by the distribution. The installed
component includes complete license and third-party notice files. Their
recorded hashes are in `TOOLCHAIN-PROVENANCE.yaml`. Commercial use,
modification, and redistribution are permitted; applicable notices must be
retained if the toolchain itself is redistributed. The toolchain is not
shipped with this product.

The complete Rust toolchain and standard-library notice bundles are respectively
15,380,909 bytes at SHA-256
`5b0c93fc4e6d4b072eaa521b1762d1e746f4c368f65e81a0e5308e2772dac85e`
and 1,512,520 bytes at SHA-256
`68129500b616d5838629e68f55ff3aed5e096dacf60ce9eb41bbe599a563afa6`.
They enumerate Rust contributors and applicable third-party rightsholders.
Clippy's Apache-2.0 and MIT notices are 10,848 and 1,081 bytes at the hashes
recorded in the provenance ledger.

## Acquisition Tools

The selected one-time acquisition tools are not build or runtime
dependencies:

- `/usr/bin/curl`: curl 8.7.1, SHA-256
  `b636262803922ee1dd0fbf614818473ffa53c811e44fd3278c2270d3af4759d3`,
  source tag `curl-8_7_1`, commit
  `de7b3e89218467159a7af72d58cea8425946e97d`, curl license, complete license
  SHA-256
  `adb1fc06547fd136244179809f7b7c2d2ae6c4534f160aa513af9b6a12866a32`.
- `/usr/bin/tar`: bsdtar 3.5.3 with libarchive 3.7.4, SHA-256
  `f96200d5be4a3f99cdbc88892a2e26f14d501d354c72b224472462cc67fa271d`,
  upstream commits `673c1eae896c837081a627807b9d5e990684dbf7` and
  `313aa1fa10b657de791e3202c168a6c833bc3543`, BSD-2-Clause, complete license
  SHA-256
  `b2cdf763345de2de34cebf54394df3c61a105c3b71288603c251f2fa638200ba`.

All downloads used HTTPS from the official Rust distribution or immutable
public source paths. No credentials, private registry, Amazon-specific tool,
or Amazon-internal endpoint was used.

## Invocation Rules

Cargo and rustc are invoked by their exact workspace-local paths with an empty
or enumerated environment, offline mode, fixed locale/timezone, explicit
target, fixed SDK root, `linker-flavor=ld`, the admitted bundled linker, and
the bundled LLVM library path. A tool hash or version mismatch is a hard
failure.

`tools/validate-p01` uses the already admitted `/usr/bin/ruby`; its only added
process helper is Ruby's bundled `open3.rb`, SHA-256
`9f9a0c275058b66dd1daa9b3c0823db9d9494c387f7840041f82189a0c9230fd`,
under the same Ruby/BSD license scope recorded for that runtime.

## Failure And Resumption Evidence

The first P01 test invocation selected `ld64.lld` with Rust's default
compiler-driver argument flavor. It first failed to locate `libLLVM.dylib`,
then rejected compiler-driver flags after the library path was supplied. This
was an invocation defect, not a product-code failure.

The resumption fixed the selected configuration to `linker-flavor=ld`, supplied
the bundled LLVM library path, and fixed `SDKROOT`. The complete P01 gate then
passed formatting, Clippy with warnings denied, tests, and all-target builds
under the sanitized offline environment.
