# P14 Noise Source Promotion

- Input checkpoint: `c7d517c52ab725ff5d12be8b8351b0986294ea04`
- Source evidence: `docs/evidence/P13-NOISE-SOURCES.yaml`
- Package count: `23`
- Historical schema-1 aggregate:
  `f2856930555547530c12b316856f2bd3e29407b12c63117a35fa65318c6067e6`
- Current schema-3 aggregate:
  `e769386d042e9ea34223c30f357d5a41fc0052a65dcf7279dc0f51c842de4a84`
- State: `PROMOTED_PENDING_NATIVE_LINUX_ADMISSION`

## Identity Transition

The historical report and the current Git-mode-aware projection use different
tree digest schemas. The exact transition is machine-readable below. Git
object IDs use this repository's SHA-1 object format; package aggregate and
tree digests use SHA-256.

<!-- P14_NOISE_IDENTITY_JSON_BEGIN -->
```json
{
  "current": {
    "aggregate_package_tree_sha256": "e769386d042e9ea34223c30f357d5a41fc0052a65dcf7279dc0f51c842de4a84",
    "manifest_blob": "7fa0ca965ea6dd3ea9a840f42d35ef1524855501",
    "schema_version": 3,
    "tree_digest_domain": "P14_NOISE_TREE_V3"
  },
  "historical": {
    "aggregate_package_tree_sha256": "f2856930555547530c12b316856f2bd3e29407b12c63117a35fa65318c6067e6",
    "commit": "52f0f36ec79ffa30317ca9b8ec8efc6b695bb885",
    "manifest_blob": "270f5fa44b7276a880fd77eb35dbdaa4edc65dcd",
    "schema_version": 1,
    "tree": "379992ee8f96263677e825def2bdfbe245640302"
  }
}
```
<!-- P14_NOISE_IDENTITY_JSON_END -->

## Carry-forward Disposition

The first P14 promotion attempt invoked the complete P13 aggregate and failed
closed with:

```text
P14_NOISE_SOURCE_PROMOTION_FAIL: P13 source acquisition fetch tool size differs
```

This is the stale P13 self-binding anticipated by the user-directed transition.
P13 was not patched or rerun. P14 instead performs a new source-focused
admission operation that:

1. verifies the immutable P13 evidence semantic digest and selected profile;
2. verifies the material-ledger closure binding;
3. verifies the pinned Noise specification and removed Cacophony origin;
4. reopens and hashes every one of the 23 immutable crate archives;
5. replays every selected projection, replacement, deletion, and notice;
6. repeats the complete retained-source origin review;
7. repeats the pinned RustSec advisory review;
8. emits Cargo checksum manifests over the promoted projected bytes; and
9. refuses to overwrite a differing package or manifest.

The promotion command and immediate replay both passed:

```text
tools/promote-p14-noise-sources --write
P14_NOISE_SOURCE_PROMOTION_PASS
P14_NOISE_SOURCE_PACKAGE_COUNT=23

tools/promote-p14-noise-sources --check
P14_NOISE_SOURCE_PROMOTION_PASS
P14_NOISE_SOURCE_PACKAGE_COUNT=23
```

The exact package identities, archive hashes, selected licenses, source modes,
and promoted tree hashes are in
`vendor/p14-noise-source-manifest.json`. Schema 3 binds every projected entry's
relative path, entry type, Git executable mode, and bytes under the
`P14_NOISE_TREE_V3` digest domain before computing the package aggregate.

## Admission Boundary

This evidence supersedes only the stale P13 acquisition-tool self-binding for
P14 source promotion. It does not claim native file reachability, executable
product admission, packaging admission, or runtime enablement.

ADR-0039 transfers the remaining native gate to P15 because this P14 executor
has no admitted Linux runtime. Before either architecture can be enabled, P15
must build and execute the selected channel on Linux amd64 and aarch64 from a
kernel-enforced read-only source snapshot and prove that rejected source is
unreachable. Artifact production remains disabled until that gate passes.
