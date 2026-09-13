# MLP security, privacy, licensing, and package review

- Subject commit: `86e19910481c4d0b3b008002728938b3ad3a9fd3`
- Subject tree: `624dd3cc70d13280deb37ab189bd9923e6104632`
- Review mode: read-only isolated Git archive
- Verdict: **PASS**

The reviewer inspected endpoint resolution, authorization and exposure
revalidation, HTTP bounds, privacy, licenses, exact vendoring, container
inputs, and both distributable directories. `./tools/mlp-check` passed on the
subject tree.

Verified closures include:

- public, metadata, legacy numeric, and DNS-rebinding endpoints fail closed;
- each awaited domain service batch refetches the caller and revalidates live
  permission and exposure;
- outbound requests, inbound requests, responses, query labels, and aggregate
  query results are bounded;
- HTTP handling has an absolute deadline and at most 16 active connections;
- the add-on, integration, and image layout include project and selected
  third-party license notices;
- all 14 vendored crates are bound to checksum-matching archives and exact
  extracted-tree manifests;
- the Rust builder OCI index and amd64/aarch64 manifests are pinned; and
- the runtime image is `scratch`, non-root, and contains no Home Assistant
  credential or API authority.

No P0, P1, or P2 finding remains. One accepted P3 limitation remains: this
host has no Docker, Podman, or Buildah, so it could not execute the OCI image.
The exact archived add-on source built successfully offline, and source,
package, metadata, and local release-binary checks passed.
