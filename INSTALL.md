# Arandu NLU — Installation, update, and releases

This repository is a monorepo. The two distributables are built from it,
but neither is published by the steps below. No command here pushes,
tags remotely, or publishes anything.

## What gets installed

| Piece | Source in this repo | Version anchor |
|---|---|---|
| Add-on (Rust service) | `addon/` | `addon/config.yaml` (`version`), must equal integration version |
| Integration (HA custom component) | `custom_components/local_nlu/` | `manifest.json` (`version`) |
| Engine crate (built into the image) | `addon/engine/` | `Cargo.toml` + `Cargo.lock` (`local-nlu`) |

All four carry the same version (currently `0.2.0`). A release sets all
four, never a subset.

## Add-on installation

This repository root is a valid Home Assistant store: `repository.yaml`
plus one add-on directory `ptbr_nlu/` (an exact copy of `addon/`,
verified byte-identical). Supported routes:

1. **Store install (primary for GitHub users).** In Home Assistant go
   to Settings → Add-ons → Add-on Store → ⋮ → Repositories and add
   `https://github.com/jaimevictor/Arandu-NLU`. Install "Local PT-BR
   NLU" from the store list, start it, and check the log for a clean
   start. Slug `ptbr_nlu`; health `GET /health` →
   `{"status":"ok","version":1}`. The API is not published to the home
   network (no host port mapping); the integration reaches it over the
   internal Supervisor network only.
2. **Supervisor local add-on.** Copy the `ptbr_nlu/` directory to the
   host add-ons folder, then install from the local section.
3. **Docker build (verified).** With the pinned toolchain image
   available, from `ptbr_nlu/` (or `addon/`, identical content):
   `docker build --network none --platform linux/amd64 --tag
   'local-nlu:<ver>-amd64' --build-arg BUILD_ARCH=amd64 --build-arg
   BUILD_VERSION=<ver> .`
   The build is hermetic (vendored crates, `--locked`, pinned base
   digest in `Dockerfile` and `container-inputs.json`). aarch64 also
   builds (buildx) and serves `/health` under emulation.

## Integration installation (manual only, no HACS)

There is deliberately no HACS support and the add-on never installs the
integration: the two pieces ship and update independently.

Copy `custom_components/local_nlu/` (exactly the 14 files of the
integration package, no `__pycache__`) to
`<ha-config>/custom_components/`, restart Home Assistant, then
Settings → Devices & Services → Add Integration → "Local NLU"
(single instance). Restart is required by Home Assistant for new
custom components, not by this integration.

## Endpoint configuration (all install routes)

There is no auto-discovery; the origin is entered once and validated.
Supervisor DNS names follow `{REPO}_{SLUG}` with `_` mapped to `-`:

1. **Local add-on installs**: `{REPO}` is `local`, so the default
   `http://local-ptbr-nlu:11555` (`const.DEFAULT_ENDPOINT`) resolves.
2. **GitHub store installs**: `{REPO}` is the 8-hex-digit SHA-1 of the
   lowercased store repository URL. For this repository
   (`https://github.com/jaimevictor/Arandu-NLU`) the hash is `18b0d50a`,
   so the hostname is `http://18b0d50a-ptbr-nlu:11555` (verified against
   the client allowlist). Recompute after any repo rename/transfer with:
   `python3 -c "import hashlib; print(hashlib.sha1(
   b'<store-url>'.lower()).hexdigest()[:8])"`
   and confirm it in Supervisor → Add-ons → the add-on, or via the
   Supervisor API `/addons` endpoint, which lists repository identifiers.
3. The config flow accepts only local origins (loopback, RFC 1918, ULA,
   `localhost`, single-label `local-*`, single-label
   `<8hex>-ptbr-nlu`, `.local`, `.home.arpa`), plain HTTP, no
   credentials, no path/query — anything else, including arbitrary
   single-label names, numeric-IP forms, and public origins, is rejected
   before any network use (`client.normalize_endpoint` plus DNS pinning,
   which drops every resolution outside local ranges).
4. The flow then performs a live `GET /health` and aborts with
   `cannot_connect` unless the add-on answers
   `{"status":"ok","version":1}`. A wrong hostname therefore fails
   loudly at setup time, never silently at runtime.

## Updating

1. Back up the HA configuration (standard HA backup covers both pieces;
   neither piece keeps state worth migrating: no migration exists).
2. Update the add-on first (reinstall image / re-copy), verify
   `/health`, then update the integration files and restart HA.
3. Re-enter the entry options only if behavior changed (options persist
   across file updates; both feature flags default off).
4. Roll back by reinstalling the previous versions of both pieces;
   protocol v1 behavior is frozen and baseline-pinned, so downgrades do
   not strand the integration.

## Versioning and releases (maintainer procedure, local only)

1. Set the same version in `custom_components/local_nlu/manifest.json`,
   `addon/config.yaml`, `addon/engine/Cargo.toml`, and the
   `local-nlu` entry of `addon/engine/Cargo.lock`.
2. Re-run the full gate set (Rust tests, clippy, fmt, Python tests,
   ER/extraction/v2 freezes and oracles, `regression_gate.py` 144/144 +
   23/23) and record the engine-source divergence if `addon/engine/src`
   changed (never rewrite a freeze).
3. Build the add-on image per the Docker command above and smoke-test
   `/health`, one v1 plan, and one v2 plan.
4. Assemble artifacts: `arandu-nlu-addon-<ver>` (exact `addon/` tree),
   `arandu-nlu-integration-<ver>` (exact `custom_components/local_nlu/`
   tree). Never include `target/`, `work/`, residential data, or
   credentials (enforced by `.gitignore`).
5. Create the GitHub release with those artifacts and tag `v<ver>`
   locally; push tag and branch only with explicit owner approval.

## What is intentionally not distributed

Legacy phase tooling stays in the tree (the standard gate depends on
it) but ships in no artifact. `work/`, residential data, credentials,
and local machine setup never enter version control (`.gitignore`).
Evaluation corpora are synthetic, Apache-2.0, and published as
conformance evidence, not as product payloads.
