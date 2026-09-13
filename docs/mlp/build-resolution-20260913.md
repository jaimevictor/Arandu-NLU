# Build blocker resolution — 2026-09-13

## Result

CONFIRMADO: All three reported local build blockers are resolved through the
Docker-based developer environment described in `BUILD-WINDOWS.md`.

| Blocker | Evidence |
| --- | --- |
| Rust 1.98 unavailable | Exact existing Rust image digest pulled; `rustc 1.98.0 (88d9e12ae 2026-08-18)` and Cargo 1.98.0 executed successfully |
| No compiled binary | `target/release/local-nlu` built and passed the existing service smoke test; Linux amd64 add-on image built and passed a separate runtime test |
| Ruby unavailable | Ruby 3.4.4 executed the existing frozen generator; regeneration produced byte-identical corpus files |

This installs project tooling inside Linux containers, not global Windows
Rust/Ruby commands. Docker Desktop was present but stopped; it was started.
No Claude, OmniRoute, Caveman, or global PATH settings were changed.

## Full gate

`tools/mlp-dev.ps1 check` ran the original `tools/mlp-check`, ending in
`MLP CHECK PASS`. Evidence: `build-check-20260913.log`.

- frozen corpus reproducibility;
- exact vendored-source integrity and package structure;
- JSON/YAML validation;
- 21 Python integration/protocol tests;
- Rust formatting and Clippy with warnings denied;
- 13 Rust tests: 5 unit, 4 corpus/protocol, 4 HTTP;
- locked, offline release build; and
- black-box release-binary health and ordered mixed-action smoke test.

`tools/mlp-dev.ps1 corpus` also completed. SHA-256 checks against
`build-baseline-20260913.json` confirmed that all 13 recorded engine/corpus/pin
files remain byte-identical. The corpus is Apache-2.0 project-authored internal
conformance data under `CORPUS-SPEC.md`; no linguistic data was invented or
imported to fix these blockers.

## Artifacts

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `target/release/local-nlu` | 3,106,184 bytes | `b39a6ad8789d3ad7a012f3b310de8ce3269b5c63f7cd31475e81572d1f803040` |
| `target/local-nlu-0.1.0-amd64.tar` | 1,363,456 bytes | `cfc9559a886b20b7298c85898e5b13ce2177660b1a173beb01a9debbe8348f68` |

The archive is a `docker save` export of `local-nlu:0.1.0-amd64`, image ID
`sha256:37f3ed88caa2e1ba756db7ef8a0118d4cf264819afd96793d90effa013d7fc8c`.
The standalone workspace binary and Dockerfile-built binary are separate
builds; both were tested, and they are not claimed byte-identical.

The actual scratch image ran with user `65534:65534`, read-only filesystem,
all capabilities dropped, and no-new-privileges. Its loopback-only test port
returned the expected health JSON and the frozen ordered-mixed-actions plan.
The temporary test container was removed. See `image-build-20260913.log` and
`image-smoke-20260913.json`.

DESCONHECIDO: Actual Home Assistant installation and aarch64 execution have not
been tested here. No external host was deployed to. The delivered prebuilt
artifacts are Linux amd64; the original Home Assistant installation procedure
and aarch64 build recipe remain available.

## Narrow repairs and preserved checks

- Restored the missing root `LICENSE` from the two identical existing license
  copies in the add-on and companion integration.
- Added the missing root Cargo configuration selecting `addon/vendor` offline.
- Added developer-only Docker/PowerShell/Python launch tooling.
- Staged the Windows checkout into a fresh Linux filesystem to recover Unix
  modes before the existing package-tree verifier runs. The executable mode
  of `unicode-normalization`'s `scripts/unicode.py` was checked against the
  crates.io archive with SHA-256
  `5fd4f6878c9cb28d874b009da9e8d183b5abc80117c40bbd187a1fde336be6e8`.

No engine code, test expectation, generator, dependency version, Rust pin,
vendor checksum, vendor manifest, or production Dockerfile was changed.

INFERIDO: The Windows extraction lost Unix file-mode information. CONFIRMADO:
all vendored file-content checksums matched before repair, while tree checks
failed on the direct Windows mount and passed after Linux staging. The
integrity rules were not relaxed.

## Tool provenance and licenses

| Tool/input | Exact version | License/elected branch | Provenance and purpose |
| --- | --- | --- | --- |
| Rust/Cargo, Clippy, rustfmt | 1.98.0 | MIT OR Apache-2.0; toolchain's LLVM notices retained upstream | Existing pinned official `rust:1.98.0-alpine3.22` image in `addon/container-inputs.json`; rustup installs the matching formatter/linter |
| Ruby and standard library | Alpine `3.4.4-r0` | BSD-2-Clause alternative for Ruby core; MIT for bundled MIT components | `https://www.ruby-lang.org/`; generates frozen corpus and parses package metadata |
| Ruby YAML | Alpine `0.4.0-r1` | MIT | `https://rubygems.org/gems/yaml`; YAML metadata checks |
| LibYAML | Alpine `0.2.5-r2` | MIT | `https://pyyaml.org/wiki/LibYAML`; Ruby YAML parser support |
| Python | Alpine `3.12.14-r0` | PSF-2.0 | `https://www.python.org/`; tests, package verifier, developer staging, and binary smoke test |

All 50 installed APK package versions, license declarations, upstream URLs,
and Alpine source commits are retained in `build-apk-inventory-20260913.json`;
the raw installed-package database and version output are retained beside it.
This inventory records installed packages, not a claim that every bundled
component was executed. The developer image is not part of the runtime image.

Source discrepancy: Alpine labels Ruby `Ruby AND BSD-2-Clause AND MIT`.
The exact Ruby 3.4.4 upstream [COPYING file](https://github.com/ruby/ruby/blob/v3_4_4/COPYING)
expressly allows the BSD-2-Clause alternative for the Ruby core. This setup
elects that OSI-approved alternative and retains MIT component obligations;
it does not treat the custom Ruby license as independently OSI-approved.

## Historical evidence and reviews

The older release notes describe a successful build on a different release
subject, while the local audit reported missing tools. Neither establishes
the state of this extracted checkout. This report records commands executed
against the current checkout; no unavailable original Git commit is claimed.

Two read-only reviews covered build correctness and security/package boundaries
after the passing gate. Both found no material implementation defect. Their
documentation findings were to supply this report and tool licensing inventory;
these are addressed here. Reviewers did not independently rerun the entire gate
or validate an actual Home Assistant installation.
