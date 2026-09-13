# Build and test on Windows

Run these commands in PowerShell from `Complete MLP`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mlp-dev.ps1 check
```

The developer script uses Docker Desktop in Linux-container mode. It builds a
local tool image from the project's exact Rust 1.98.0 Alpine image, installs
Clippy, rustfmt, Ruby 3.4.4 with JSON/YAML, and Python 3.12.14, then runs the
existing `tools/mlp-check` gate with networking disabled. The first setup needs
internet access to download the pinned builder and development tools.

It does not install native Windows `cargo` or `ruby` commands. Use this wrapper
for project commands; no global PATH or Claude/OmniRoute settings are changed.
Docker Desktop is the existing ambient host virtualization boundary; only the
separate scratch add-on image is a distributable runtime artifact.

## Commands

| Task | Command argument | Output |
| --- | --- | --- |
| Full gate | `check` | Corpus/package checks, Python and Rust tests, formatting, linting, release build, service smoke test |
| Release binary | `build` | `target/release/local-nlu`, a Linux amd64 executable |
| Check corpus | `corpus-check` | Exact comparison with the frozen generator |
| Regenerate corpus | `corpus` | The two existing files in `data/mlp` |
| Tool versions | `versions` | Rust, Cargo, Ruby, and Python versions |
| Build add-on image | `image` | Docker image `local-nlu:0.1.0-amd64` |

For example:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mlp-dev.ps1 corpus
powershell -NoProfile -ExecutionPolicy Bypass -File tools/mlp-dev.ps1 image
```

The frozen corpus is project-authored Apache-2.0 internal conformance data,
not independent linguistic evaluation. Regeneration runs the existing Ruby
generator; it does not invent examples or obtain data from model outputs.

## Why Linux staging is necessary

The vendor manifest includes Unix permissions in each package-tree hash.
A Windows bind mount presents different permissions, even when every file's
content checksum matches. The developer runner copies the active checkout into
a fresh Linux filesystem with the original modes, then runs the original exact
vendor verifier unchanged. The one executable vendored file's permission is
documented in `tools/dev/run.py` with its checked archive hash. A future change
to the frozen dependency set must still satisfy the existing verifier.

The host checkout is mounted read-only. Only `target` is writable during checks
and builds. `corpus` additionally mounts `data/mlp` for its explicitly requested
output. The Linux toolchain is selected by environment variable so the original
Mac target in `rust-toolchain.toml` is not downloaded; the Rust version pin is
unchanged.

## Artifacts and deployment

The binary runs on Linux amd64, not as a Windows `.exe`. The add-on's original
Dockerfile packages a non-root scratch image with its license files. It remains
the Home Assistant build recipe described in `INSTALL.md`.

To move a locally built image to another amd64 Docker host:

```powershell
docker save --output target/local-nlu-0.1.0-amd64.tar local-nlu:0.1.0-amd64
```

Load that archive with `docker load --input ...` on the destination. Home
Assistant Supervisor installation still uses the local add-on directory and
the companion integration as documented in `INSTALL.md`. A Windows build does
not itself install the integration into Home Assistant. The local image build
command targets amd64; the existing recipe also declares aarch64, which needs
its own target build.

## Scope and provenance

`tools/dev/Dockerfile` and `tools/dev/run.py` are developer tools, not a runtime
supervisor or part of the add-on image. The root `LICENSE` was restored from
the identical existing `addon/LICENSE` and integration license. The missing
root `.cargo/config.toml` now selects the already-vendored `addon/vendor` tree
and offline resolution. No engine behavior, source data, dependency version,
or production Dockerfile was changed to address these blockers.

The builder is pinned to the existing OCI digest; direct added APK versions
are pinned in the developer Dockerfile. Transitive APK versions are captured
with the validation evidence, rather than claimed to be independently pinned.
See `build-resolution-20260913.md` for results and remaining deployment limits.
