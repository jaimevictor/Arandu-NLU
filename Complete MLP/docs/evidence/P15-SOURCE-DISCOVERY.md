# P15 Source Discovery And Convergence Pass One

- Phase: `P15`
- Date: 2026-09-10
- Input commit: `7ad4bcb6e568438269a61a9704e669de1bbd3e62`
- Input tree: `00a1dfe98bed337f9f8b39273fb1e7456365a95e`
- Pass unit: one integrated evaluator, benchmark, native executor, root
  filesystem, Home Assistant lifecycle, artifact, and evidence portfolio
- Pass: `1 of 3`
- Result: `SELECTED_WITH_UNMET_EXTERNAL_PRECONDITIONS`
- Decision: `ADR-0045`

## Host Inventory

The current arm64 macOS executor has the admitted Rust 1.98
`aarch64-apple-darwin` toolchain and project host validators. It has no
admitted Linux virtual machine or container executor, native Linux amd64
host, Linux Rust target standard library, musl or glibc runtime closure, OCI
executor, Home Assistant Supervisor runtime, or real supported Home Assistant
runtime closure.

The following shortcuts are ineligible:

- cross-compilation or emulation presented as native execution;
- architecture labels without matching ELF machine identity and execution;
- Docker Desktop or another proprietary distribution;
- an official image without complete layer-to-source and license closure;
- the rejected Homebrew CPython 3.14.6 environment;
- the unreviewed 105-distribution Home Assistant virtual environment; and
- mocks presented as real installation or lifecycle evidence.

## Latest Home Assistant Identity

The official latest-release endpoint resolved on 2026-09-10 to `2026.9.1`.

| Field | Exact identity |
| --- | --- |
| Tag | `2026.9.1` |
| Commit | `fc034572d0216a04ed40a07154394908a594dfed` |
| Tree | `4b2a1cd29e3d85c43d791e03eb82a17244956fec` |
| Commit date | `2026-09-05T14:53:30+02:00` |
| Deterministic git archive bytes | `215511040` |
| Deterministic git archive SHA-256 | `ef440c5b9809036416901238c5fff4f9139acd9814fc142c1998bfd1fc572ea4` |
| `LICENSE.md` bytes | `11357` |
| `LICENSE.md` SHA-256 | `c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4` |
| `pyproject.toml` SHA-256 | `e4d4e9f4a275e9c7e738f4be38514cefdc76205303b6b810e3d444b453482047` |
| Package constraints SHA-256 | `d8dd403ea5b7ad91ebae51f1483bc0111ec866f503eba5cc4c644f8222559863` |
| Declared Python floor | `>=3.14.2` |
| Latest-response bytes | `220191` |
| Latest-response SHA-256 | `1bd9c88c4175b5ef72767adaf2ac9449384117bd5f0dd4d7d89d24ce9737b195` |

The source remains `QUARANTINED_CANDIDATE`. The full Python, package,
Supervisor, OCI executor, and native binary closures are not admitted. No
runtime or compatibility PASS follows from source identity inspection.

## Evaluation Portfolio

The frozen P02 inputs permit:

- 4,800 clean-text held-out plan cases;
- 4,800 clean-text performance plan cases;
- at least 240 cases in every recorded mandatory clean-text performance and
  held-out stratum; and
- 27 non-plan cases across safety-sensitive, contradiction, ambiguity,
  stale-state, and explicit-negative suites.

They do not contain an ASR-noise accuracy stratum. P15 therefore reports ASR
as `INSUFFICIENTLY_EVALUATED` and makes no ASR support claim. Clarification
and abstention are reported as separate non-plan safety metrics, not as
Wilson-backed supported accuracy strata.

The selected implementation uses a sealed aggregate-only runner over the
actual protocol-v2 `NluRuntime::dispatch_at` path. Mechanical suite contexts
may be added as `FIXTURE_TECNICA`; suite utterances and outcomes may not
change.

## Ranked Release Portfolios

### Selected: scratch, musl, native Linux

Required admission remains:

- native Linux amd64 and aarch64 machines;
- Rust 1.98 native host toolchains and both musl target libraries;
- exact linker, musl CRT/libc, and source-to-binary closure;
- an admitted OCI executor;
- complete Home Assistant Core, Supervisor, Python, and package closure; and
- real lifecycle environments on both architectures.

Project-authored code emits deterministic ustar, OCI, SBOM, notices,
checksums, and release reconciliation.

### Bounded fallback: minimal dynamic GNU root filesystem

This may be selected only after an actual admitted native test proves scratch
incompatible with required Supervisor behavior. It adds glibc loader, libc,
NSS, root-filesystem, source, and notice closure.

### Rejected: official images plus general container/SBOM stacks

Official base images with Docker, Podman, Buildah, Skopeo, Syft, or similar
tools have a substantially larger unadmitted closure and are not the minimum
bounded portfolio.

## Pass Disposition

Pass one freezes the architecture and source portfolio but does not freeze a
P15 review candidate. Safe implementation work may continue. Artifact
production, architecture enablement, native PASS, real Home Assistant PASS,
and release-readiness claims remain prohibited until the listed external
preconditions and inherited P14 debt pass.

## Primary Commands

```text
command -v docker podman nerdctl lima colima qemu buildah skopeo
git ls-remote --refs --tags https://github.com/home-assistant/core.git 2026.9.*
git clone --depth 1 --branch 2026.9.1 --single-branch
git rev-parse HEAD^{commit} HEAD^{tree}
git archive --format=tar --prefix=home-assistant-core-2026.9.1/ 2026.9.1
shasum -a 256 LICENSE.md pyproject.toml homeassistant/package_constraints.txt
```

No sibling directory, prohibited source, closed engine, Amazon-specific
material, credential, or residential data was inspected.
